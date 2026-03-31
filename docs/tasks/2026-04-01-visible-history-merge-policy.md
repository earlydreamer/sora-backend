# Codex 위임 작업

## Codex 위임 작업

**상태**: done
**출처**: direct-to-codex intake
**목표**: GUI 히스토리 추적 관점을 반영해 non-squash merge 기본 정책을 backend 운영 문서에 명시한다.

**배경**:
- Fork 같은 GUI Git 클라이언트에서 `main` 히스토리를 직접 따라가며 작업 맥락을 추적한다.
- squash merge를 기본값으로 두면 의미 단위 커밋이 `main`에 바로 보이지 않아 handoff와 추적 비용이 커진다.

**수정 대상 파일**:
- `AGENTS.md` — merge 규칙에 GUI 히스토리 가시성과 squash 지양 원칙을 명시한다.
- `docs/operations/github-task-pipeline.md` — merge 전략 기본값과 예외 조건을 문서화한다.
- `docs/current.md` — 필요 시 현재 운영 원칙 요약을 최신화한다.

**비범위**:
- 코드 동작 변경
- CI 구성 변경
- 기존 merge된 커밋 히스토리 재작성

**완료 조건**:
- [x] `rg -n "squash|GUI|Fork|merge 전략" AGENTS.md docs/operations/github-task-pipeline.md docs/current.md`
- [x] `git diff -- AGENTS.md docs/operations/github-task-pipeline.md docs/current.md docs/tasks/2026-04-01-visible-history-merge-policy.md`
- [x] 문서 간 merge 정책 표현이 충돌하지 않는다.

**Claude 재호출 조건**:
- merge 정책을 저장소별로 다르게 가져가야 한다는 결정이 새로 필요할 때
- 문서 수정 범위를 넘어 GitHub 자동화나 브랜치 전략 자체를 바꿔야 할 때
- 다른 저장소와의 통합 정책 결정이 필요할 때

**참고**:
- GitHub issue #21
- GUI 클라이언트 기준 추적성 요구
