# start-harness 트리거 구조 정비

날짜: 2026-03-31
작업자: Codex

## 작업 범위
`start-harness`를 얇은 트리거 오케스트레이터로 다시 정의하고, backend 저장소의 tmux helper와 테스트 계약을 그 해석에 맞게 정렬했다.

## 변경 내용
- 글로벌 `start-harness` skill, 설치본 skill pack, agent용 pack 문서를 thin trigger + minimal bootstrap + mode-aware GitHub gate + downstream ownership 구조로 다시 작성했다.
- backend `agent-handoff-harness.md`, `tmux-orchestration.md`, `.gitignore`를 실제 런타임 계약과 맞게 보강했다.
- `scripts/orchestrator/lib.sh`에 state upsert helper를 추가하고 `spawn-worker`, `mark-worker`, `recover-session`이 `state.json`과 worker JSON을 함께 동기화하도록 수정했다.
- `scripts/test-tmux-integration.sh`를 실제 설치 경로, tmux live smoke, queue/spawn/capture/dashboard/recover, state sync까지 검증하는 실패 가능 테스트로 재작성했다.

## 결정 사항
- `start-harness`는 구현·검증·복구를 모두 직접 수행하는 완결형 skill이 아니라, 적절한 downstream workflow를 선택해 연결하는 얇은 트리거로 본다.
- `gh` readiness는 모든 `/start-harness` 호출의 전역 preflight가 아니라, tracked task 생성과 PR/merge 같은 GitHub 단계에서만 hard gate로 적용한다.
- Verify/Correct 책임은 gstack, superpowers, repo verification, tmux helper에 분산할 수 있으며, 핵심은 그 소유권을 문서에 명시하는 것이다.

## 다음 스텝
- backend 변경을 한국어 커밋과 PR로 정리한다.
- frontend 저장소에 같은 원칙을 별도 issue/branch로 반영한다.
