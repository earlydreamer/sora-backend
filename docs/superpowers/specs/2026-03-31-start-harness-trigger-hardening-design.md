# start-harness 트리거 구조 개선 설계

작성일: 2026-03-31
프로젝트: `sora-backend`
상태: 구현 승인 완료, Codex 작업 시작

## 요약

`start-harness`는 완결형 하네스가 아니라, 적절한 skill/command/workflow를 자동 선택해 다음 실행 주체에게 넘기는 얇은 트리거 오케스트레이터로 유지한다. 이번 개선의 목표는 이 정체성을 문서와 설치본 skill pack, backend 저장소의 tmux 오케스트레이터 문서/스크립트/테스트에 일관되게 반영하는 것이다.

## 목표

- `start-harness`의 책임을 "thin trigger + downstream ownership"으로 명확히 한다.
- 선읽기 문맥과 GitHub 게이트를 실제 필요 시점 기준으로 줄여 과도한 부트 비용을 없앤다.
- Verify/Correct 책임이 gstack, superpowers, tmux helper script, review loop에 분산된 구조를 문서에 명시한다.
- tmux 기반 worker spawn/list/capture/recover/dashboard 흐름이 실제 실행과 테스트에서 일관되게 동작하도록 맞춘다.
- backend에서 안정화한 뒤 같은 구조를 frontend에도 반영할 수 있는 기준을 만든다.

## 비목표

- `start-harness` 자체가 planning, review, verification, recovery를 모두 직접 수행하도록 만들지 않는다.
- gstack 또는 superpowers 내부 구현을 수정하지 않는다.
- tmux 오케스트레이터를 새로운 daemon 구조로 갈아엎지 않는다.

## 현재 문제

- 홈 디렉터리의 `start-harness` skill과 `~/.claude/skills/start-harness-pack` 설치본의 계약이 다르다.
- skill 문서가 얇은 트리거인지, 완결형 실행 스킬인지 해석 여지가 있다.
- `Read First`와 GitHub 준비도 체크가 너무 이른 시점에 걸려 단순 재개나 로컬 분석 흐름까지 무겁게 만든다.
- tmux helper script는 꽤 성숙했지만 테스트와 문서가 설치본 skill pack의 계약과 완전히 맞물리지는 않는다.

## 결정

### 1. 트리거와 실행 책임을 분리한다

`start-harness`는 아래 4가지만 책임진다.

- 최소 문맥 부트
- 요청 분류와 모드 선택
- 가장 적절한 downstream skill/command/workflow 트리거
- 상태판과 work spec을 다음 실행 주체가 이어받을 수 있게 정리

실제 설계, 구현, review, verification, recovery는 downstream 주체가 담당한다.

### 2. 선읽기 문맥은 2단계로 나눈다

항상 읽는 문맥:

- `AGENTS.md`
- `docs/current.md`

조건부 지연 로드 문맥:

- 활성 스펙
- `docs/operations/agent-handoff-harness.md`
- `docs/operations/github-task-pipeline.md`
- tmux 관련 운영 문서

즉, 라우팅 전에 모든 문서를 강제로 적재하지 않는다.

### 3. GitHub 게이트는 유지하되 시점을 뒤로 미룬다

저장소 계약인 `1 작업 = 1 이슈 = 1 브랜치 = 1 PR`은 그대로 유지한다. 다만 `gh` 인증과 GitHub hard gate는 "새 tracked task 시작 / issue branch 생성 / PR 생성 / merge" 경로에서만 강제한다.

즉, 아래 흐름은 로컬에서 먼저 계속 진행할 수 있다.

- 활성 스펙 재개
- `docs-only`
- 로컬 review 해석
- debugging triage
- tmux worker 상태 점검/복구

### 4. 분산된 Verify/Correct 책임을 문서에 명시한다

`start-harness`는 검증과 복구를 직접 다 하지 않는다. 대신 선택된 흐름이 아래 책임을 이어받도록 연결한다.

- Verify:
  - repo build/lint/test
  - `verification-before-completion`
  - gstack `/review`, `/qa`
  - repo-local verification script
- Correct:
  - review-loop cap
  - tmux helper script (`recover-session`, `capture-worker`, `dashboard`)
  - retry / stale / blocked 상태 전이
  - 문서 정규화와 garbage collection 성격의 follow-up task

### 5. tmux 계약을 설치본 skill pack과 일치시킨다

설치본 skill pack, probe, backend helper script, integration/unit test가 동일한 경로와 상태 이름을 기준으로 동작해야 한다. tmux 기반 "parallel workers"는 skill 문구가 아니라 실제 스크립트와 테스트를 통해 검증한다.

## 구현 범위

- `/mnt/c/Users/early/.codex/skills/start-harness/SKILL.md`
- `/mnt/c/Users/early/.claude/skills/start-harness-pack/SKILL.md`
- `/mnt/c/Users/early/.claude/skills/start-harness-pack/scripts/probe.sh`
- backend 저장소의 `docs/current.md`, `docs/tasks/`, `docs/operations/agent-handoff-harness.md`, `docs/operations/tmux-orchestration.md`
- backend 저장소의 `scripts/orchestrator/*`, `scripts/test-tmux-unit.sh`, `scripts/test-tmux-integration.sh`

## 완료 판정

- `start-harness` 문서가 얇은 트리거 구조로 읽히고, 실행 책임이 downstream ownership 형태로 분명히 드러난다.
- backend 저장소의 tmux helper script와 테스트가 이 계약을 반영한다.
- 실제 tmux 세션에서 spawn/list/capture/recover/dashboard/queue 흐름을 반복 검증해 치명적 오작동이 없다.
- 같은 구조를 frontend 저장소에도 복제 가능한 수준으로 안정화된다.
