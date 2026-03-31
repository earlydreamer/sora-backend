# 하네스 구현 여정과 트러블슈팅 기록

날짜: 2026-04-01  
작업자: Codex  
대상 저장소: `sora-backend`

## 이 문서의 목적

이 문서는 `start-harness`, handoff harness, tmux 오케스트레이션이 어떤 문제의식에서 시작됐고, 어떤 순서로 구현됐으며, 실제 운영 중 어떤 문제를 만났고 어떻게 풀었는지를 사람이 읽기 쉽게 정리한 기록이다.  
Notion에 옮길 때도 바로 사용할 수 있도록, 설계 의도보다 "왜 이렇게 바뀌었는가"와 "운영하면서 무엇이 실제로 문제였는가"에 초점을 맞춘다.

## 한 줄 요약

이번 하네스 작업의 핵심은 "Claude와 Codex를 문서 상태로 느슨하게 연결하는 handoff contract"를 만들고, `/start-harness`를 모든 일을 직접 하는 두꺼운 스킬이 아니라 적절한 downstream workflow를 선택하는 얇은 트리거로 재정의한 뒤, 그 실행층을 tmux worker helper와 실제 Codex CLI까지 포함해 끝까지 검증한 것이다.

## 출발점

처음 문제는 단순했다. Claude는 판단과 구조화에는 강하지만 반복 구현과 디버깅은 Codex가 더 잘한다. 그런데 둘을 사람이 매번 손으로 연결하면 흐름이 끊기고, review 이후 수정이나 direct-to-codex 요청에서도 일관성이 깨졌다.

그래서 초기에 세운 원칙은 아래 다섯 가지였다.

1. 하네스는 "명령 이력"이 아니라 "상태와 산출물" 기준으로 동작해야 한다.
2. 구현 시작 게이트는 slash command가 아니라 `docs/current.md`와 활성 스펙이어야 한다.
3. direct-to-codex 요청도 허용하되 intake와 문서 게이트는 우회하지 못해야 한다.
4. 저장소별 예외는 `AGENTS.md`와 운영 문서에만 두고, 공통 구조는 최대한 유지해야 한다.
5. 최종적으로는 실제 Codex CLI가 tmux에서 안정적으로 돌아야 한다.

## 구현 여정

### 1. 상태 기반 handoff contract 설계

첫 단계는 하네스를 slash command 묶음이 아니라 상태 머신으로 보는 관점 정리였다.  
이 시점에 `claude-triage`, `codex-ready`, `codex-in-progress`, `needs-claude-decision`, `done` 같은 상태 이름과, `docs/current.md` + `docs/tasks/*.md` 조합이 구현 시작 게이트라는 원칙이 정리됐다.

이 결정으로 얻은 이점은 컸다.

- review 이후 수정
- 일반 구현 요청
- direct-to-codex 요청
- 컨텍스트 재시작 후 재개

이 네 가지를 같은 구조로 다룰 수 있게 됐다.

### 2. 운영 문서와 템플릿 rollout

설계만으로는 실제 운영이 되지 않기 때문에, 다음 단계에서는 문서 구조를 저장소에 심었다.

- `docs/operations/agent-handoff-harness.md`
- `docs/tasks/` 템플릿
- `docs/current.md`의 하네스 상태 섹션
- `AGENTS.md`의 강제 규칙

여기서 중요했던 건 "사람이 바뀌어도 같은 로컬 경로를 열면 바로 이어받을 수 있어야 한다"는 점이었다.  
즉 GitHub의 원격 상태보다 로컬 문서와 작업 디렉터리 상태를 더 높은 진실 원천으로 두는 방향이 명확해졌다.

### 3. tmux 실행층 도입

다음 단계는 문서 계약을 실제 실행으로 연결하는 것이었다.  
`spawn-worker`, `list-workers`, `capture-worker`, `mark-worker`, `recover-session`, `dashboard`, `enqueue-worker` 같은 helper script가 이 시점에 생겼다.

이 계층의 역할은 분명했다.

- 문서는 "어떤 흐름을 탈지" 결정한다.
- tmux helper는 "그 흐름을 어떻게 실제로 굴릴지" 담당한다.

이 구분이 생기면서 `/start-harness` 자체를 과도하게 무겁게 만들 필요가 없어졌다.

### 4. `start-harness` 재정의

초기 문맥에서는 `start-harness`가 모든 문서를 읽고, GitHub 준비도도 먼저 확인하고, 검증과 복구까지 거의 다 끌어안는 방향으로 읽힐 여지가 있었다.  
하지만 실제 의도는 전혀 달랐다.

`start-harness`의 본래 목적은 다음과 같았다.

- 프롬프트와 명령어를 읽는다.
- 가장 적절한 specialist path를 고른다.
- 문서 상태를 정렬한다.
- downstream skill, workflow, worker path를 트리거한다.

즉 이 스킬은 "완결형 하네스"가 아니라 "오케스트레이션 진입점"이어야 했다.

이 해석에 맞춰 다음 개념이 들어갔다.

- minimal bootstrap context
- mode-aware GitHub gate
- downstream ownership
- worker dispatch for an active spec

### 5. 실제 runtime 문제 해결

문서와 테스트가 어느 정도 맞아도, 실제 tmux 안에서 진짜 `codex exec`가 돌아가지 않으면 하네스는 완성이라고 볼 수 없었다.  
그래서 마지막 단계는 "실제로 돌려보는 것"이었다.

여기서 가장 큰 문제는 Codex runtime state였다. 데스크톱 Codex 앱과 tmux worker가 같은 `~/.codex`를 공유하면서 `state_5.sqlite`, `logs_1.sqlite` 경고가 발생했다.  
결론은 간단했다. 설정과 인증은 공유해도 되지만, SQLite 상태 계층은 공유하면 안 됐다.

그래서 최종적으로는 worker마다 아래 경로를 별도 runtime home으로 쓰도록 정리했다.

```text
.orchestrator/runtime/codex-home/<worker-id>
```

그리고 실제 tmux worker 안에서 재검증해 다음을 확인했다.

- `EXIT_CODE=0`
- `RESULT=TMUX_ISOLATED_OK`
- `HAS_LOGS_IO_ERROR=0`
- `HAS_STATE_WARNING=0`

즉 "문서상으로 맞다"가 아니라 "실제 tmux Codex worker가 안정적으로 동작한다"까지 확인한 상태가 됐다.

## 가장 중요했던 설계 전환

### 1. command 중심에서 state 중심으로

처음에는 `/review`, `/qa`, `/start-harness` 같은 명령 이름이 중심처럼 보였지만, 실제로는 명령보다 상태가 중요했다.  
어떤 명령으로 들어왔든 결국 구현 가능 여부는 활성 스펙과 `docs/current.md` 상태가 결정한다는 관점으로 바뀌었다.

### 2. 두꺼운 하네스에서 얇은 트리거로

`start-harness`가 구현, 검증, 복구까지 모두 들고 있으면 문맥은 무거워지고 책임은 모호해진다.  
그래서 이 스킬은 "최소한의 문맥만 읽고, 가장 적절한 downstream path를 고르는 얇은 트리거"로 재정의됐다.

### 3. 전역 GitHub preflight에서 mode-aware gate로

한동안은 `gh` 설치와 인증이 모든 흐름의 공통 진입 게이트처럼 앞에 있었다.  
하지만 이 방식은 `docs-only`, 활성 스펙 재개, tmux 상태 점검 같은 로컬 흐름까지 불필요하게 막았다.

결국 GitHub gate는 없애는 것이 아니라, 정말 GitHub가 필요한 순간으로 옮기는 게 맞았다.

- issue 생성
- issue branch 생성
- PR 생성/merge
- GitHub 정리를 포함한 완료 선언

즉 `1 작업 = 1 이슈 = 1 브랜치 = 1 PR` 구조는 유지하되, hard gate의 시점을 뒤로 미뤘다.

### 4. 중앙집중 Verify/Correct에서 분산 ownership으로

초기 비판 중 하나는 Verify와 Correct가 `start-harness`에 충분히 명시되지 않았다는 점이었다.  
재검토 결과, 문제는 기능 부재보다 "책임이 어디에 있는지 문서에 잘 안 보였다"는 쪽에 가까웠다.

정리된 구조는 다음과 같다.

- `start-harness`: 라우팅과 entry/exit gate
- gstack, superpowers, repo verification: Verify
- tmux helper, `recover-session`, retry, review-loop cap: Correct

즉 핵심은 "한 곳에 다 넣는 것"이 아니라 "누가 무엇을 맡는지 분명하게 보이게 하는 것"이었다.

## 실제 트러블슈팅 기록

### 1. `Read First` 문맥이 너무 무거웠다

초기 구조는 `/start-harness` 호출 때마다 너무 많은 운영 문서를 선적재하는 방식으로 읽힐 수 있었다.  
문제는 단순 재개나 `docs-only` 같은 요청에서도 동일한 부트 비용을 내야 한다는 점이었다.

해결:

- 항상 읽는 문서는 `AGENTS.md`, `docs/current.md`로 제한
- 활성 스펙은 필요할 때만 읽기
- GitHub 파이프라인 문서는 tracked-task 경로에 들어갈 때만 읽기

### 2. GitHub gate가 너무 빨랐다

이건 실제 review finding으로도 드러난 문제였다.  
`gh` 설치/인증 체크가 모드 선택 이전에 하드 게이트처럼 앞에 오면, 로컬 흐름까지 전부 막히게 된다.

해결:

- `GH_READY`를 전역 preflight가 아니라 capability flag로 해석
- GitHub가 정말 필요한 모드에서만 하드 게이트 적용

### 3. tmux 상태와 worker JSON이 자주 어긋났다

실제 스크립트를 굴려보니 `workers/*.json`, `state.json`, 실제 tmux window 상태가 서로 어긋나는 경우가 있었다.  
이 문제는 복구 시 판단을 흐리게 하고, dashboard도 신뢰하기 어렵게 만든다.

해결:

- `spawn-worker`, `mark-worker`, `recover-session`이 state 요약과 worker JSON을 함께 갱신
- `capture-worker`는 pane 0을 명시적으로 캡처
- `dashboard`와 `list-workers`는 runtime 상태를 읽는 읽기 계층으로 정리

### 4. pane/log 동작이 생각보다 쉽게 깨졌다

`--split-log`를 붙였을 때 worker 명령이 잘못된 pane으로 들어가거나, 실제 stdout이 로그 파일에 남지 않는 문제가 있었다.

해결:

- split 후 항상 pane 0으로 worker 명령 전달
- 필요 시 `tee`를 붙여 실제 출력이 로그에도 남게 수정
- 로그 함수는 stderr로 분리해 stdout 오염 방지

### 5. worker ID와 window naming이 실제 운영에서 불안정했다

`worker-${worker_id}-...` 같은 중복 prefix, 삭제 후 ID 재사용, queue 처리 중 충돌 가능성 같은 것들이 실제로는 꽤 큰 운영 비용을 만들었다.

해결:

- window name 규칙 단순화
- `next_worker_id()`를 max suffix + 1 방식으로 변경
- queue 실패 시 복구 로직 추가

### 6. 실제 Codex runtime 충돌

가장 중요한 운영 이슈였다.  
데스크톱 Codex, tmux worker, 수동 CLI가 같은 `~/.codex`를 공유하면 SQLite state/log 레이어가 충돌할 수 있었다.

해결:

- worker별 repo-local `CODEX_HOME` 준비
- `auth.json`, `config.toml`, `skills`, `plugins`만 공유
- `state_5.sqlite`, `logs_1.sqlite`, `sessions/`는 worker별 분리

결과적으로 이 문제를 풀고 나서야 tmux 경로를 "실사용 가능" 상태로 볼 수 있었다.

### 7. 남은 경고

현재도 일부 MCP/plugin에서 OAuth `invalid_token` 경고가 남아 있다.  
다만 이건 tmux worker 실행 성공 여부를 가르는 blocker는 아니고, 플러그인 인증 정리 문제에 가깝다.

즉 지금의 운영 상태는 "하네스 자체는 동작한다. 다만 연결된 일부 외부 plugin 자격 증명은 정리 여지가 있다" 정도로 보는 게 정확하다.

## 현재 도달한 운영 형태

지금의 하네스는 아래처럼 이해하면 가장 정확하다.

- `docs/current.md`와 활성 스펙이 구현 게이트다.
- `/start-harness`는 얇은 트리거다.
- specialist skill, gstack, superpowers, repo-local workflow가 실제 작업을 담당한다.
- 병렬 경로가 필요하면 tmux helper가 실행층이 된다.
- completion은 문서 상태, 검증, GitHub 정리, 로컬 작업 디렉터리 정렬까지 포함한다.

즉 이제 하네스는 "문서만 있는 설계"도 아니고 "스킬 설명만 있는 관념"도 아니다.  
문서 계약, 실행 스크립트, 테스트, 실제 tmux 검증이 연결된 운영 시스템에 가까워졌다.

## 남은 과제

1. MCP/plugin OAuth 토큰 정리
2. frontend 저장소에서 tmux helper를 도입할 경우 같은 runtime isolation 계약 재사용
3. 필요하면 Notion용 더 짧은 요약본 추가 작성

## Notion으로 옮길 때 추천 목차

이 문서를 Notion에 정리할 때는 아래 구조로 옮기면 읽기 편하다.

1. 왜 이 하네스를 만들었는가
2. 핵심 설계 원칙
3. 단계별 구현 여정
4. 실제 트러블슈팅 5~7개
5. 현재 운영 표준
6. 남은 리스크와 후속 과제

## 참고 문서

- `docs/history/2026-03-30-agent-handoff-harness-design.md`
- `docs/history/2026-03-31-agent-handoff-harness-rollout.md`
- `docs/history/2026-03-31-start-harness-trigger-hardening.md`
- `docs/history/2026-04-01-tmux-codex-runtime-isolation.md`
- `docs/operations/agent-handoff-harness.md`
- `docs/operations/tmux-orchestration.md`
