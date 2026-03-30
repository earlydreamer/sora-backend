# handoff harness rollout 계획 작성

날짜: 2026-03-31
작업자: Codex

## 작업 범위

승인된 spec을 바탕으로 backend 저장소에서 실제 문서와 규칙을 반영하기 위한 rollout implementation plan을 작성했다.

## 변경 내용

- `docs/operations/agent-handoff-harness.md` 추가 계획을 문서화했다.
- `AGENTS.md`, `docs/tasks/`, `docs/current.md` 반영 작업을 단계별 task로 쪼갰다.
- frontend 저장소 반영은 별도 후속 계획으로 분리했다.

## 결정 사항

- 이번 plan은 backend 로컬 저장소 안에서 독립 실행 가능한 범위만 다룬다.
- direct-to-codex 대응도 backend rollout 안에 포함한다.

## 다음 스텝

- plan 검토 후 실행 방식 선택
