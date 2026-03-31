# Codex 위임 작업

## Codex 위임 작업

**상태**: done
**출처**: direct-to-codex intake
**목표**: `start-harness`를 얇은 트리거 오케스트레이터로 재정의하고 backend tmux 오케스트레이션 계약과 테스트를 실제 동작 기준으로 정비한다.

**배경**:
- `start-harness`의 의도는 gstack/superpowers/저장소 workflow를 자동 선택해 트리거하고, 상세 동작은 downstream skill과 worker/subagent에게 넘기는 것이다.
- 현재 skill 원본, 설치된 `start-harness-pack`, backend 저장소의 tmux helper script/test 계약이 조금씩 어긋나 있어 해석 오차가 생긴다.
- `1 작업 = 1 이슈 = 1 브랜치 = 1 PR` 구조는 유지하되 GitHub hard gate를 실제 필요 시점으로 옮기고, Verify/Correct 책임의 분산 구조를 명시해야 한다.

**수정 대상 파일**:
- `/mnt/c/Users/early/.codex/skills/start-harness/SKILL.md` — thin trigger + downstream ownership 구조로 문구 정비
- `/mnt/c/Users/early/.claude/skills/start-harness-pack/SKILL.md` — 설치본 skill pack 동기화
- `/mnt/c/Users/early/.claude/skills/start-harness-pack/scripts/probe.sh` — mode-aware GitHub readiness, tmux 감지 계약 정비
- `docs/current.md` — 활성 작업 상태판 갱신
- `docs/operations/agent-handoff-harness.md` — 분산된 Verify/Correct 책임과 tmux 경로 보완
- `docs/operations/tmux-orchestration.md` — 실제 검증 흐름과 helper script 계약 정비
- `scripts/orchestrator/*` — 필요한 범위 내 상태 전이/복구/출력 계약 정비
- `scripts/test-tmux-unit.sh` — 새 계약을 기준으로 red-green 보강
- `scripts/test-tmux-integration.sh` — 설치본 skill pack과 실제 tmux 흐름 검증 보강

**비범위**:
- gstack 또는 superpowers 내부 구현 수정
- 새로운 daemon/서비스형 오케스트레이터 도입
- backend와 frontend를 하나의 통합 스펙으로 처리

**완료 조건**:
- [x] `npm run build`
- [x] `npm run lint`
- [x] `npm test -- --runInBand --passWithNoTests`
- [x] `scripts/test-tmux-unit.sh`
- [x] `scripts/test-tmux-integration.sh`
- [x] 실제 tmux 세션에서 spawn/list/capture/recover/dashboard/queue 흐름을 확인하고 오작동이 없음을 기록
- [x] `start-harness` 문서가 thin trigger + downstream ownership 구조로 읽히도록 정리

**Claude 재호출 조건**:
- 새로운 하네스 상태 이름 추가가 필요한 경우
- 저장소 운영 계약 자체를 뒤집는 구조 변경이 필요한 경우
- cross-repo 통합 spec이 필요하다고 판단되는 경우
- GitHub 파이프라인 자체 규칙을 바꿔야 하는 경우

**참고**:
- GitHub issue: #19
- branch: `codex/19-start-harness-orchestration-hardening`
- 설계 문서: `docs/superpowers/specs/2026-03-31-start-harness-trigger-hardening-design.md`
- 계획 문서: `docs/superpowers/plans/2026-03-31-start-harness-trigger-hardening.md`
