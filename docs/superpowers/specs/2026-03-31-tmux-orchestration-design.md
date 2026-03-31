# tmux 기반 멀티에이전트 오케스트레이션 설계

작성일: 2026-03-31
프로젝트: `sora-backend`
상태: 1단계 문서 계약 반영 완료, 시험 적용 대기

## 요약

기존 handoff harness와 skill 기반 워크플로우 위에 `tmux`를 실행·가시화 레이어로 추가한다. 이때 Claude는 초기 컨트롤러 역할을 맡지만, 구조 자체는 Claude 전용이 아니라 Codex나 Gemini도 중간부터 이어받을 수 있는 `agent-agnostic` 규약으로 설계한다. 사람에게는 `docs/current.md`와 `docs/tasks/*.md`가 현재 맥락을 제공하고, 에이전트와 스크립트에게는 `.orchestrator/*.json`이 런타임 상태와 복구 정보를 제공한다. `tmux`에서는 저장소당 세션 하나를 두고, `window 하나 = 서브에이전트 하나` 원칙으로 격리와 가시성을 확보한다.

## 목표

- `ssh`로 원격 접속한 뒤 터미널에서 여러 서브에이전트의 진행 상태를 시각적으로 확인할 수 있어야 한다.
- Claude가 오케스트레이션을 시작하더라도, Claude 세션 종료나 토큰 제한 이후 Codex나 Gemini가 같은 작업을 이어받을 수 있어야 한다.
- 기존 `docs/current.md`, `docs/tasks/`, `start-harness` 흐름을 버리지 않고 그 위에 `tmux` 제어를 얹는다.
- `tmux`의 `new-window`, `send-keys`, `capture-pane`, `remain-on-exit`, hooks 같은 안정적인 기본 기능만으로 최소 운영이 가능해야 한다.
- 초기 단계에서는 helper script 기반으로 구현하고, 이후 필요하면 TUI나 daemon으로 확장할 수 있어야 한다.

## 비목표

- 지금 단계에서 중앙 daemon, 메시지 브로커, 웹 대시보드를 도입하지 않는다.
- Claude, Codex, Gemini의 내부 프로토콜이나 IPC를 직접 연결하지 않는다.
- 이 설계에서 에이전트 모델별 프롬프트 템플릿 세부 문구까지 고정하지 않는다.
- 첫 단계에서 pane 중심 레이아웃, 복잡한 tiled dashboard, 자동 재배치까지 구현하지 않는다.

## 문제 배경

현재 저장소는 문서 기반 handoff harness를 갖고 있고, `docs/current.md`와 `docs/tasks/*.md`를 통해 구현 게이트를 관리한다. 하지만 실제 구현을 병렬화하거나 여러 서브에이전트의 출력을 한눈에 보려면, 문서만으로는 런타임 상태를 표현하기 어렵다. 또한 Claude가 상위 조정자로 동작하는 동안 토큰 제한이나 세션 종료가 발생하면, 그 시점의 작업 배정과 워커 상태가 Claude 내부 컨텍스트에만 남아 있을 위험이 있다.

따라서 런타임 상태를 에이전트 바깥으로 끌어내고, `tmux`를 통해 실행 상태를 눈으로 확인하면서도 복구 가능한 구조가 필요하다. 이때 저장소 정책상 사람용 맥락 문서와 기계용 실행 상태는 구분하는 편이 안전하다.

## 결정

오케스트레이션은 `tmux window 중심`으로 설계한다. 저장소당 `tmux session` 하나를 만들고, `window 0`은 `control`, 나머지 `worker-*` window는 서브에이전트 전용으로 사용한다. 각 worker window에서는 실제 Codex CLI, Gemini CLI, 혹은 다른 워커 프로세스가 실행된다.

런타임 상태는 Markdown이 아니라 JSON으로 저장한다. 다만 기존 문서 하네스와 충돌하지 않도록, 사람용 상태는 계속 `docs/current.md`와 `docs/tasks/*.md`에 두고, `.orchestrator/` 아래에 기계용 상태를 별도로 둔다. 결과적으로 이 설계는 `MD + JSON 이중 레이어`를 채택한다.

또한 Claude는 이 구조의 첫 번째 컨트롤러일 뿐, 유일한 컨트롤러가 아니다. 새 에이전트가 들어오면 `docs/current.md`, 활성 스펙, `.orchestrator/state.json`, `tmux list-windows`, `capture-pane` 결과를 대조해 현재 상태를 복구하고 이어서 제어할 수 있어야 한다.

## 설계 원칙

### 1. 실행과 가시화는 `tmux`

- 실제 워커 프로세스는 `tmux` window 안에서 돈다.
- 사람이 `tmux attach`만 해도 어떤 워커가 어떤 작업을 하는지 볼 수 있어야 한다.
- pane은 나중에 로그 보조 뷰로 추가할 수 있지만, 초기 운영 단위는 window로 고정한다.

### 2. 상태는 외부화

- 컨트롤러의 내부 컨텍스트는 진실 원천이 아니다.
- 활성 워커, task 배정, heartbeat, 마지막 출력 시각, blocked 이유는 파일에 남아야 한다.
- Claude가 멈춰도 다른 에이전트가 같은 상태를 읽어 복구할 수 있어야 한다.

### 3. 기존 하네스와 정합성 유지

- `docs/current.md`와 `docs/tasks/*.md`가 여전히 사람 기준 운영 진실 원천이다.
- `.orchestrator/*.json`은 런타임 보조 계층이 아니라, 기계 기준 운영 진실 원천이다.
- 둘이 충돌하면 정규화 절차를 거친 뒤 진행한다.

### 4. helper script 우선

- 에이전트가 저수준 `tmux` 명령을 직접 조합하는 대신 공통 helper script를 사용한다.
- 같은 helper script를 Claude, Codex, Gemini가 공유해야 재현성과 복구성이 좋아진다.

## 아키텍처

### 세션 구조

```text
tmux session: sora-backend
  window 0: control
  window 1: worker-001-codex-<slug>
  window 2: worker-002-gemini-<slug>
  window 3: worker-003-codex-<slug>
```

### 실행 환경

#### WSL2 (Ubuntu 22.04+)

- Windows PC의 WSL2에서 tmux 세션을 운영한다.
- systemd는 반드시 활성화한다. `/etc/wsl.conf`에 `systemd=true`가 있어야 한다.
- 저장소 경로는 `/mnt/d/Projects/sora/sora-backend`를 기준으로 한다.
- 기본 tmux 세션명은 `sora-backend`다.

#### SSH 접근 (Tailscale VPN)

- WSL 내부에서 `openssh-server`를 사용해 SSH 접속을 받는다.
- 외부 접근은 Tailscale VPN으로 암호화하고 공개 포트 노출은 피한다.
- SSH 인증은 공개 키 인증만 허용하고 비밀번호 인증은 비활성화하는 것을 기본 정책으로 둔다.

#### 제어 경로

경로 A: Windows Claude Code 앱
- Windows 쪽 Claude Code 앱이 WSL 명령을 호출해 tmux 세션과 helper script를 제어한다.
- 이때 Bash 명령은 WSL 컨텍스트를 명시해 실행한다.

경로 B: SSH + tmux/WSL CLI
- Tailscale VPN을 통해 WSL SSH에 접속한다.
- `tmux attach -t sora-backend`로 실시간 모니터링한다.
- WSL 내부의 Claude Code CLI, Codex CLI, Gemini CLI가 같은 helper script 규약을 읽고 제어를 이어받는다.

### 역할 분리

- `control`
  - 현재 활성 스펙 확인
  - worker 생성/회수/재시도 결정
  - worker 상태 집계
  - 복구 진입점
- `worker-*`
  - 실제 서브에이전트 프로세스 실행
  - 한 window는 하나의 task만 담당
  - stdout은 화면과 로그 파일 둘 다로 남김

### 컨트롤 플레인과 워커 플레인

- 컨트롤 플레인: Claude, Codex, Gemini 중 현재 제어권을 가진 에이전트
- 워커 플레인: `tmux`의 `worker-*` window들
- 저장 계층:
  - 사람용: `docs/current.md`, `docs/tasks/*.md`
  - 기계용: `.orchestrator/state.json`, `.orchestrator/workers/*.json`

## 파일 구조와 git 정책

### 저장소 추적 대상

- `docs/operations/tmux-orchestration.md` 같은 운영 문서
- `docs/superpowers/specs/2026-03-31-tmux-orchestration-design.md` 같은 설계 문서
- `scripts/orchestrator/` 아래 helper script들
- `.orchestrator/scripts/` 같은 향후 정적 스크립트 자산

### 저장소 제외 대상 (`.gitignore`)

- `.orchestrator/state.json` — 런타임 세션 상태
- `.orchestrator/queue.json` — 런타임 작업 큐
- `.orchestrator/workers/*.json` — 워커 인스턴스 상태
- `.orchestrator/logs/` — 워커 실행 로그

### 파일 사례

```text
.orchestrator/
  scripts/              <- git 추적
    orchestrator/
  state.json            <- .gitignore (runtime)
  queue.json            <- .gitignore (runtime)
  workers/              <- .gitignore (runtime)
    worker-001.json
  logs/                 <- .gitignore (temporary)
    worker-001.log
```

## 상태 모델

### 사람용 문서

- `docs/current.md`
  - 현재 저장소 상태
  - 활성 스펙
  - 현재 담당 에이전트
- `docs/tasks/*.md`
  - 작업 목표
  - 범위와 비범위
  - 완료 조건
  - Claude 재호출 조건

### 기계용 상태

#### `.orchestrator/state.json`

세션 단위 메타데이터를 담는다.

```json
{
  "session_id": "sora-backend",
  "repo_path": "/mnt/d/Projects/sora/sora-backend",
  "control_window": "control",
  "active_spec": "docs/tasks/2026-03-31-tmux-orchestration.md",
  "controller": {
    "agent": "claude",
    "status": "running",
    "last_heartbeat": "2026-03-31T14:00:00+09:00"
  },
  "workers": ["worker-001", "worker-002"]
}
```

#### `.orchestrator/workers/<worker-id>.json`

worker와 `tmux` window의 1:1 매핑을 담는다.

```json
{
  "worker_id": "worker-001",
  "agent": "codex",
  "tmux_window": "worker-001-codex-routes",
  "status": "running",
  "task_ref": "task-1",
  "spec_path": "docs/tasks/2026-03-31-tmux-orchestration.md",
  "log_path": ".orchestrator/logs/worker-001.log",
  "started_at": "2026-03-31T14:05:00+09:00",
  "last_heartbeat": "2026-03-31T14:09:00+09:00",
  "last_output_at": "2026-03-31T14:09:00+09:00",
  "owner": "controller"
}
```

### 상태 enum

초기 범위에서는 아래 값만 사용한다.

- `idle`
- `starting`
- `running`
- `blocked`
- `done`
- `failed`
- `stale`

## tmux 운영 규약

### window 네이밍

`worker-<seq>-<agent>-<slug>` 형식을 사용한다.

예시:

- `worker-001-codex-routes`
- `worker-002-gemini-review`
- `worker-003-codex-testfix`

이름 규칙만으로도 사람이 역할을 이해할 수 있고, 스크립트가 정규식으로 파싱할 수 있다.

### control window

- 이름은 항상 `control`
- 세션당 하나만 유지
- 컨트롤러가 상태판과 복구 진입점으로 사용

### remain-on-exit

- worker window는 기본적으로 `remain-on-exit on` 정책을 사용한다.
- 프로세스가 종료된 뒤에도 마지막 출력이 남아 있어 복구와 디버깅이 쉬워진다.
- 종료된 worker는 컨트롤러가 명시적으로 정리한다.

### 로그 보존

- `capture-pane` 결과만 믿지 않고, worker 실행 시 로그 파일에도 append한다.
- `tmux` 화면은 실시간 관찰용, 로그 파일은 사후 분석용으로 구분한다.

## 제어 흐름

### 정상 실행

1. 컨트롤러가 `docs/current.md`와 활성 스펙을 읽는다.
2. 구현 가능한 task를 서브태스크로 분해한다.
3. `spawn-worker`로 새 worker window를 만든다.
4. helper script가 `tmux new-window`와 worker JSON 생성을 함께 처리한다.
5. 컨트롤러는 주기적으로 `list-workers`, `capture-worker`를 호출해 상태를 갱신한다.
6. worker가 `done` 또는 `blocked`가 되면 후속 task를 배정하거나 정리한다.

### blocked 처리

- worker가 구조 변경, 스키마 변경, 범위 확장 같은 결정 경계를 만나면 `blocked`로 전환한다.
- 이유는 worker JSON의 `blocker_reason`과 로그에 남긴다.
- 컨트롤러는 이를 보고 `needs-claude-decision` 혹은 후속 task 분리로 연결한다.

### 완료 처리

- worker가 완료되면 `done` 상태로 마킹한다.
- 검증 전용 worker가 별도로 필요하면 `review` 또는 `verify` 성격의 worker를 새로 연다.
- 모든 관련 worker가 종료되면 세션 상태를 `done`으로 정리한다.

## 복구 규약

### 복구 목표

Claude 세션 종료, 토큰 제한, SSH 연결 종료, 컨트롤러 교체가 발생해도 저장소 작업은 이어질 수 있어야 한다.

### 복구 절차

새 컨트롤러는 아래 순서를 반드시 따른다.

1. `AGENTS.md` 읽기
2. `docs/current.md` 읽기
3. 활성 스펙 읽기
4. `.orchestrator/state.json` 읽기 (WSL 기준 경로: `/mnt/d/Projects/sora/sora-backend`)
5. `tmux list-windows`로 실제 window 목록 조회
6. `workers/*.json`과 실제 window를 대조
7. 각 worker의 최근 출력 50~200줄을 `capture-pane`으로 확인
8. 상태를 `running`, `blocked`, `done`, `stale`, `failed` 중 하나로 정규화
9. 정규화 결과를 JSON에 다시 기록
10. 이후 오케스트레이션 재개

### 충돌 처리

- window는 살아 있는데 worker JSON이 없으면 `orphan-window`로 간주하고 수동 확인 또는 신규 worker 등록 절차를 밟는다.
- worker JSON은 있는데 window가 없으면 `stale` 또는 `failed` 후보로 보고 최근 로그를 확인한다.
- `docs/current.md`의 활성 스펙과 JSON의 `active_spec`이 다르면 문서 정규화를 먼저 수행한다.
- 사람이 보는 맥락은 `docs/current.md`, 실제 실행 존재 여부는 `tmux`, 기계 상태 캐시는 JSON으로 본다.

## helper script 계약

### `spawn-worker`

- 입력:
  - `agent`
  - `slug`
  - `task_ref`
  - `spec_path`
  - `command`
- 동작:
  - 새 worker ID 할당
  - `tmux new-window` 생성
  - 로그 파일 준비
  - worker JSON 생성
  - 필요 시 초기 명령 주입

### `list-workers`

- 입력 없음 또는 `--json`
- 동작:
  - 등록된 worker와 실제 `tmux` window 상태를 요약
  - 사람용과 기계용 출력 모두 지원 가능

### `capture-worker`

- 입력:
  - `worker_id`
  - `--lines N`
- 동작:
  - 대응하는 window의 최근 출력 캡처
  - 복구와 상태판 갱신에 사용

### `mark-worker`

- 입력:
  - `worker_id`
  - `status`
  - `reason`
- 동작:
  - worker JSON 상태를 갱신
  - blocked, done, failed 같은 명시적 상태 전이를 기록

### `recover-session`

- 입력:
  - `session_id`
- 동작:
  - `state.json`, `workers/*.json`, 실제 `tmux` window를 대조
  - 복구 후보와 불일치 목록을 출력
  - 필요 시 JSON 정규화

## 기존 skill과의 연결

### `start-harness`

- active spec를 읽은 뒤 필요한 경우 worker를 배치하는 상위 진입점이 될 수 있다.
- `/start-harness` 자체가 `tmux`를 직접 제어하기보다 helper script를 호출하는 쪽이 안정적이다.

### `subagent-driven-development`

- 이미 쪼개진 구현 계획을 각 worker window에 배정하는 방식으로 활용 가능하다.
- 단, 현재 세션 안의 가상 서브에이전트만이 아니라 실제 terminal worker로 투영된다는 차이가 있다.

### `dispatching-parallel-agents`

- 독립적인 task 2개 이상이 확인되면 worker 2개 이상을 동시에 띄우는 판단 기준으로 쓸 수 있다.

### `using-git-worktrees`

- 저장소를 크게 흔드는 장기 작업은 worker별 worktree를 따로 붙이는 확장도 가능하다.
- 다만 첫 단계에서는 같은 저장소 안의 `tmux window` 격리만 지원하고, worktree는 후속 단계로 남긴다.

## 롤아웃 단계

### 1단계: 문서 계약 추가

- 이 설계를 spec으로 저장
- `docs/operations/`에 운영 절차 문서 추가
- `.orchestrator/` 디렉터리와 상태 파일 규약 문서화

### 2단계: helper script 최소 구현

- `spawn-worker`
- `list-workers`
- `capture-worker`
- `mark-worker`
- `recover-session`

이 단계에서 사람은 여전히 `tmux attach`와 기본 관찰을 직접 할 수 있어야 한다.

### 3단계: skill 연결

- `start-harness` 또는 별도 skill이 helper script를 호출하게 한다.
- Claude, Codex, Gemini가 같은 복구 순서를 따르도록 운영 문서와 스크립트 인터페이스를 고정한다.

### 4단계: 선택적 고도화

- TUI 상태판
- pane 기반 보조 로그 뷰
- worker 우선순위 큐
- 자동 재시도 정책

## 리스크와 대응

### 리스크: Claude 세션 종료 시 전체 제어가 멈춤

대응: `tmux`와 JSON 상태를 외부화하고, 새 컨트롤러가 복구 절차를 따라 이어받게 한다.

### 리스크: Markdown과 JSON 상태가 어긋남

대응: 사람용과 기계용 역할을 명확히 나누고, 복구 시 정규화 절차를 먼저 실행한다.

### 리스크: worker window가 많아져 세션이 복잡해짐

대응: 초기에 동시 worker 수를 3~5개 수준으로 제한하고, 작은 task는 하나의 worker로 묶는다.

### 리스크: 에이전트마다 제어 방식이 달라 운영이 흔들림

대응: 저수준 `tmux` 대신 helper script 계약을 공통 인터페이스로 강제한다.

### 리스크: 창은 살아 있지만 실질적으로 멈춘 worker를 놓침

대응: `last_heartbeat`, `last_output_at`, `capture-pane`를 함께 보고 `stale` 상태를 도입한다.

### 리스크: 너무 이른 daemon화로 구조가 과도해짐

대응: 첫 단계는 순수 `tmux + script + JSON`으로 제한하고, 필요성이 검증된 뒤에만 daemon을 검토한다.

## 성공 기준

- `tmux attach`만으로 현재 worker 배치와 진행 상황을 대략 파악할 수 있다.
- Claude가 중간에 멈춰도 Codex나 Gemini가 같은 세션을 복구해 이어받을 수 있다.
- 사람용 문서와 기계용 상태가 분리되어 각각의 소비자에게 읽기 쉬운 구조를 유지한다.
- 기존 handoff harness와 충돌하지 않고 `start-harness` 이후의 실행 계층으로 자연스럽게 붙는다.
- helper script만으로 최소 worker 생성, 조회, 캡처, 상태 갱신, 복구가 가능하다.

## 참고

`tmux` 공식 문서에서 이번 설계에 직접 연결되는 기능은 아래와 같다.

- 스크립팅 가능성과 고정 ID(`session_id`, `window_id`, `pane_id`)
- `send-keys`를 통한 입력 주입
- `capture-pane -p`를 통한 최근 출력 캡처
- `remain-on-exit`와 `respawn-pane/window`
- hooks와 control mode 확장 여지

관련 근거:

- [tmux Advanced Use wiki](https://github.com/tmux/tmux/wiki/Advanced-Use)
- [tmux manual page](https://manpages.ubuntu.com/manpages/focal/en/man1/tmux.1.html)

## 다음 단계

이 spec의 1단계 문서 계약이 완료되면 아래 순서로 진행한다.

- 2단계: helper script 최소 구현
  - `spawn-worker`
  - `list-workers`
  - `capture-worker`
  - `mark-worker`
  - `recover-session`
- 3단계: `start-harness` 또는 별도 skill에 연결
- 4단계: 선택적 고도화 (TUI, pane 로그 뷰)
