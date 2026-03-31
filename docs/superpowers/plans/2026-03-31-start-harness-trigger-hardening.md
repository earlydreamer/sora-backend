# start-harness 트리거 구조 개선 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `start-harness`를 얇은 트리거 오케스트레이터로 명확히 재정의하고, 설치본 skill pack과 backend tmux 오케스트레이터 계약 및 테스트를 일관되게 맞춘다.

**Architecture:** 홈 디렉터리 skill 문서는 최소 부트 + 라우팅 + downstream ownership 선언만 담당하고, backend 저장소는 tmux helper script와 테스트로 병렬 워커 실행/복구 계약을 증명한다. GitHub hard gate는 유지하되 실제 tracked task 단계에서만 강제한다.

**Tech Stack:** Markdown, Bash, tmux, jq, gh CLI, npm

---

### Task 1: 문서 게이트 정렬

**Files:**
- Create: `docs/superpowers/specs/2026-03-31-start-harness-trigger-hardening-design.md`
- Create: `docs/superpowers/plans/2026-03-31-start-harness-trigger-hardening.md`
- Create: `docs/tasks/2026-03-31-start-harness-trigger-hardening.md`
- Modify: `docs/current.md`

- [ ] 이 작업의 design/spec/plan/current 상태를 문서에 기록한다.
- [ ] `docs/current.md`를 `codex-in-progress`로 전환하고 active spec을 연결한다.

### Task 2: start-harness 문서 계약 정비

**Files:**
- Modify: `/mnt/c/Users/early/.codex/skills/start-harness/SKILL.md`
- Modify: `/mnt/c/Users/early/.claude/skills/start-harness-pack/SKILL.md`
- Modify: `/mnt/c/Users/early/.claude/skills/start-harness-pack/scripts/probe.sh`

- [ ] `Read First`를 최소 문맥 + 지연 로드 구조로 바꾼다.
- [ ] GitHub hard gate를 mode-aware 구조로 옮긴다.
- [ ] Verify/Correct 책임이 downstream ownership임을 명시한다.
- [ ] 설치본 skill pack과 codex용 원본 skill 문서가 같은 해석을 주도록 맞춘다.

### Task 3: backend tmux 오케스트레이터 계약 보강

**Files:**
- Modify: `docs/operations/agent-handoff-harness.md`
- Modify: `docs/operations/tmux-orchestration.md`
- Modify: `scripts/orchestrator/lib.sh`
- Modify: `scripts/orchestrator/spawn-worker`
- Modify: `scripts/orchestrator/list-workers`
- Modify: `scripts/orchestrator/capture-worker`
- Modify: `scripts/orchestrator/mark-worker`
- Modify: `scripts/orchestrator/recover-session`
- Modify: `scripts/orchestrator/dashboard`
- Modify: `scripts/orchestrator/enqueue-worker`

- [ ] skill 문서의 thin trigger 계약과 실제 tmux helper script 상태 전이를 맞춘다.
- [ ] 필요하면 루프/복구/정규화 관련 작은 보강을 추가한다.
- [ ] 실행 경로가 문서와 테스트에서 같은 용어를 쓰도록 맞춘다.

### Task 4: 테스트 보강과 반복 검증

**Files:**
- Modify: `scripts/test-tmux-unit.sh`
- Modify: `scripts/test-tmux-integration.sh`

- [ ] 현재 약점을 재현하는 failing check를 먼저 추가한다.
- [ ] 문서/스크립트 변경으로 테스트를 green으로 만든다.
- [ ] `npm run build`, `npm run lint`, `npm test -- --runInBand --passWithNoTests`, `scripts/test-tmux-unit.sh`, `scripts/test-tmux-integration.sh`를 실행한다.
- [ ] 실제 tmux 세션에서 spawn/list/capture/recover/dashboard/queue 흐름을 수동 검증한다.

### Task 5: frontend 반영 준비

**Files:**
- Reference only until backend verification completes

- [ ] backend에서 안정화된 구조를 요약한다.
- [ ] frontend 저장소에 별도 tracked task로 동일 구조를 반영한다.
