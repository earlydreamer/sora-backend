# tmux 오케스트레이션 운영 가이드

## 개요

이 문서는 `sora-backend` 저장소에서 WSL2 Ubuntu 기반 `tmux` 세션으로 여러 워커 에이전트를 운영하는 기본 절차를 정리한다. 런타임 상태와 복구 규약의 설계 근거는 [2026-03-31-tmux-orchestration-design.md](/mnt/d/Projects/sora/sora-backend/.worktrees/tmux-orchestration-phase1/docs/superpowers/specs/2026-03-31-tmux-orchestration-design.md)를 따른다.

초기 목표는 다음 세 가지다.

- Windows PC의 WSL2 안에서 `tmux` 세션을 안정적으로 유지한다.
- Tailscale VPN을 통해 SSH로 원격 접근해 실시간으로 세션을 관찰한다.
- 향후 helper script와 `.orchestrator/` 상태 파일이 붙었을 때도 같은 운영 절차를 재사용한다.

## 전제 조건

- Windows PC에 WSL2와 Ubuntu 22.04 이상이 설치돼 있다.
- WSL2에서 systemd가 활성화돼 있다.
- WSL 안에 `openssh-server`, `tmux`, `git`이 설치돼 있다.
- Tailscale이 설치돼 있고 대상 장치가 같은 tailnet에 연결돼 있다.
- 저장소 경로는 `/mnt/d/Projects/sora/sora-backend`를 기준으로 한다.

## WSL2 systemd 활성화

### 1. 설정 확인

```bash
cat /etc/wsl.conf
```

`[boot]` 섹션에 `systemd=true`가 있어야 한다.

### 2. 없으면 추가

```bash
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[boot]
systemd=true
EOF
```

### 3. WSL 재시작

Windows PowerShell에서 아래 명령을 실행한다.

```powershell
wsl --shutdown
```

그 뒤 WSL 터미널을 다시 연다.

### 4. 확인

```bash
systemctl status
```

PID 1의 init 프로세스가 systemd여야 한다.

## SSH 서버 설정

### 1. 설치

```bash
sudo apt update
sudo apt install -y openssh-server
```

### 2. 서비스 활성화

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
```

### 3. 포트 확인

```bash
sudo ss -tlnp | grep ssh
```

기본 포트는 22다.

### 4. 비밀번호 인증 비활성화

공개 키 인증만 사용할 계획이면 아래 설정을 적용한다.

```bash
sudo sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

## Tailscale VPN 설정

### 1. 설치 및 로그인

배포판에 맞는 공식 절차를 따르되, Ubuntu에서는 일반적으로 아래 흐름을 사용한다.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### 2. 연결 확인

```bash
tailscale status
```

여기서 WSL 장치가 tailnet에 연결돼 있어야 한다.

### 3. SSH 접속 정책

- 공개 포트 포워딩이나 라우터 포트 개방은 기본 경로로 쓰지 않는다.
- 가능하면 Tailscale이 부여한 장치 이름이나 IP를 사용해 SSH 접속한다.

## tmux 기본 운영

### 세션 생성

```bash
tmux new-session -d -s sora-backend -c /mnt/d/Projects/sora/sora-backend
tmux rename-window -t sora-backend:0 control
```

### 세션 접속

```bash
tmux attach -t sora-backend
```

### worker window 생성 예시

```bash
tmux new-window -t sora-backend -n worker-001-codex-routes -c /mnt/d/Projects/sora/sora-backend
```

### 최근 출력 확인

```bash
tmux capture-pane -pt sora-backend:worker-001-codex-routes -S -50
```

### 종료 후 화면 유지

```bash
tmux setw -t sora-backend:worker-001-codex-routes remain-on-exit on
```

## 제어 경로

### 경로 A: Windows Claude Code 앱

- Windows 쪽 Claude Code 앱이 WSL 명령을 실행해 세션을 제어한다.
- 이때 `wsl bash -lc "..."` 형태로 WSL 컨텍스트를 명시해 실행하는 것을 기본값으로 둔다.
- 작업 상태는 `docs/current.md`와 `.orchestrator/*.json`을 함께 확인한다.

### 경로 B: SSH + WSL CLI

- 외부 장치에서 Tailscale VPN을 통해 WSL SSH로 붙는다.
- `tmux attach -t sora-backend`로 현재 세션을 관찰한다.
- WSL 안의 Claude, Codex, Gemini CLI가 같은 helper script를 사용해 제어를 이어받는다.

## `.orchestrator/` 운영 규칙

### 역할 분리

- `docs/current.md`, `docs/tasks/*.md`
  - 사람용 상태와 작업 계약
- `.orchestrator/state.json`, `.orchestrator/workers/*.json`
  - 기계용 런타임 상태
- `.orchestrator/logs/`
  - worker 로그

### git 정책

- 문서와 정적 스크립트는 커밋 대상이다.
- 런타임 JSON과 로그는 커밋하지 않는다.
- 실제 `.gitignore` 반영은 helper script 도입 시점에 함께 처리한다.

## 복구 절차

컨트롤러 에이전트가 교체되면 아래 순서로 복구한다.

1. `AGENTS.md` 읽기
2. `docs/current.md` 읽기
3. 활성 스펙 읽기
4. `.orchestrator/state.json` 읽기
5. `tmux list-windows -t sora-backend` 실행
6. `workers/*.json`과 실제 window를 대조
7. `tmux capture-pane`으로 최근 출력 확인
8. `running`, `blocked`, `done`, `stale`, `failed`로 정규화

## 시범 적용 전 체크리스트

- [ ] WSL2에 systemd가 활성화돼 있다.
- [ ] `openssh-server`가 실행 중이다.
- [ ] Tailscale로 WSL 장치에 접근 가능하다.
- [ ] `tmux new-session -d -s sora-backend`가 성공한다.
- [ ] `tmux attach -t sora-backend`로 접속 가능하다.
- [ ] `control` window와 샘플 `worker-*` window를 수동으로 열고 닫을 수 있다.

## Helper Script 사용법

2단계부터 다음 5개 helper script를 사용해 워커를 자동으로 관리할 수 있다. 각 script는 `.orchestrator/` 상태 파일을 읽고 쓰며 tmux와 통신한다.

### spawn-worker

워커 생성 및 등록. 선택적으로 초기 명령을 자동 주입할 수 있다.

**기본 사용:**
```bash
scripts/orchestrator/spawn-worker codex routes task-1
```

**자동 시작 (--auto-start):**
```bash
scripts/orchestrator/spawn-worker codex routes task-1 \
  --spec "docs/tasks/2026-03-31-routes.md" \
  --auto-start
```

이 경우 새 window가 생성된 뒤 자동으로:
```bash
cd /mnt/d/Projects/sora/sora-backend && claude "docs/tasks/2026-03-31-routes.md를 읽고 구현해줘"
```

**커스텀 명령:**
```bash
scripts/orchestrator/spawn-worker codex auth auth-impl \
  --command "npm run build && npm run lint"
```

### list-workers

등록된 모든 워커와 실제 tmux window 상태를 비교해 조회한다.

**인간 친화적 출력:**
```bash
scripts/orchestrator/list-workers
```

**JSON 출력 (프로그래매틱 처리용):**
```bash
scripts/orchestrator/list-workers --json
```

### capture-worker

특정 워커의 최근 출력을 캡처한다. 복구, 디버깅, 상태 확인에 유용하다.

```bash
scripts/orchestrator/capture-worker worker-001
scripts/orchestrator/capture-worker worker-001 --lines 100
```

### mark-worker

워커의 상태를 명시적으로 업데이트하고 전이를 기록한다.

```bash
scripts/orchestrator/mark-worker worker-001 running
scripts/orchestrator/mark-worker worker-001 done
scripts/orchestrator/mark-worker worker-001 blocked "DB 연결 필요"
scripts/orchestrator/mark-worker worker-001 failed "타임아웃"
```

### recover-session

`.orchestrator/` 상태 파일과 실제 tmux window를 대조하고 불일치를 찾는다.

```bash
# 상태 확인만
scripts/orchestrator/recover-session

# 자동 수정
scripts/orchestrator/recover-session --auto-fix
```

## .orchestrator 상태 파일 구조

### state.json 예시

```json
{
  "session_id": "sora-backend",
  "repo_path": "/mnt/d/Projects/sora/sora-backend",
  "control_window": "control",
  "active_spec": "docs/tasks/2026-03-31-routes.md",
  "controller": {
    "agent": "claude",
    "status": "running",
    "last_heartbeat": "2026-03-31T15:35:00+0900"
  },
  "workers": ["worker-001", "worker-002"]
}
```

### worker-*.json 예시

```json
{
  "worker_id": "worker-001",
  "agent": "codex",
  "tmux_window": "worker-001-codex-routes",
  "status": "running",
  "task_ref": "task-1",
  "spec_path": "docs/tasks/2026-03-31-routes.md",
  "log_path": ".orchestrator/logs/worker-001.log",
  "started_at": "2026-03-31T15:35:00+0900",
  "last_heartbeat": "2026-03-31T15:40:00+0900",
  "last_output_at": "2026-03-31T15:40:00+0900",
  "owner": "controller"
}
```

## 다음 단계

- 3단계에서 `start-harness` 또는 별도 skill에서 helper script를 호출하게 연결한다.
- 시범 적용에서 드러난 경로 문제나 복구 절차 누락을 다시 문서에 반영한다.

## Phase 4 고도화 기능

4단계에서 운영 편의성과 안정성을 높이는 5가지 기능이 추가되었다.

### dashboard

모든 워커의 상태를 한 화면에 ANSI 색상으로 표시하는 TUI 상태판이다.

```bash
# 실시간 갱신 (watch -n 5 내부 실행)
scripts/orchestrator/dashboard

# 단일 스냅샷 출력 후 종료
scripts/orchestrator/dashboard --once

# JSON 출력 (프로그래매틱 소비용)
scripts/orchestrator/dashboard --json
```

색상 규칙:
- 초록색: `done` (완료)
- 노란색: `running`, `starting` (진행 중)
- 빨간색: `failed`, `stale`, `blocked` (오류/중단)

### enqueue-worker

우선순위 큐(`.orchestrator/queue.json`)에 태스크를 추가한다. 우선순위는 낮을수록 먼저 실행된다 (1 = 최고 우선순위, 기본값: 5).

```bash
# 기본 사용
scripts/orchestrator/enqueue-worker codex routes task-1

# 우선순위와 스펙 파일 지정
scripts/orchestrator/enqueue-worker codex routes task-1 \
  --priority 1 \
  --spec docs/tasks/2026-03-31-routes.md
```

queue.json 구조:
```json
{
  "queue": [
    {
      "id": "q-001",
      "agent": "codex",
      "slug": "routes",
      "task_ref": "task-1",
      "spec_path": "docs/tasks/...",
      "priority": 1,
      "enqueued_at": "2026-03-31T..."
    }
  ]
}
```

### spawn-worker: --split-log 옵션

window를 main pane(70%)과 log pane(30%)으로 분할한다. log pane은 해당 워커의 로그 파일을 `tail -f`로 실시간 표시한다.

```bash
scripts/orchestrator/spawn-worker codex routes task-1 --split-log
```

### spawn-worker: --retry N 옵션

워커 실패 시 자동 재시작 횟수를 지정한다. worker.json에 `retry_count`와 `max_retries` 필드가 추가된다.

```bash
scripts/orchestrator/spawn-worker codex routes task-1 --retry 3
```

### spawn-worker: --from-queue 옵션

`.orchestrator/queue.json`에서 우선순위가 가장 높은 항목을 꺼내 워커를 생성한다.

```bash
# 큐에 태스크 추가 후 순서대로 실행
scripts/orchestrator/enqueue-worker codex auth auth-task --priority 1
scripts/orchestrator/enqueue-worker codex routes routes-task --priority 2
scripts/orchestrator/spawn-worker --from-queue  # auth-task 먼저 실행
scripts/orchestrator/spawn-worker --from-queue  # routes-task 실행
```

### recover-session: failed 워커 자동 재시도

`--auto-fix` 모드에서 `retry_count < max_retries`인 failed 워커를 자동으로 재시작한다.

```bash
scripts/orchestrator/recover-session --auto-fix
```

동작 순서:
1. window가 없는 워커를 `stale`로 표시 (기존 동작)
2. `failed` 상태이고 `retry_count < max_retries`인 워커 탐색
3. `retry_count`를 1 증가시킨 후 동일 파라미터로 `spawn-worker` 재호출
