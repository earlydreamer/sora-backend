# Claude-Codex handoff harness 설계 정리

날짜: 2026-03-30
작업자: Codex

## 작업 범위

Claude와 Codex의 역할 분리가 실제로 동작하도록, review 이후와 일반 구현 요청까지 포함한 공통 하네스 설계 규칙을 spec으로 정리했다.

## 변경 내용

- `gstack`과 `superpowers`의 경계를 상태 머신 기준으로 정리했다.
- `/review`를 유일한 진입점이 아니라 여러 입력 중 하나로 재정의했다.
- Codex 시작 조건을 `codex-ready` 산출물과 `docs/current.md` 상태로 고정했다.
- 저장소별 예외는 `AGENTS.md` 하단에서만 관리하는 구조를 제안했다.
- direct-to-codex 요청을 별도 intake branch로 추가했다.
- `docs/current.md`와 task 문서 충돌 처리, 저장소 경계 분리 규칙을 spec에 반영했다.
- 사람이 빠르게 흐름을 이해할 수 있도록 mermaid 기반 도식 설명을 spec에 추가했다.

## 결정 사항

- 하네스는 명령 이력이 아니라 상태와 산출물 기준으로 동작해야 한다.
- Claude와 Codex는 직접 연결하지 않고, 공통 문서 계약을 통해 느슨하게 연결한다.
- 백엔드와 프론트엔드는 동일한 공통 계약을 가지되 저장소별 예외만 따로 둔다.
- direct-to-codex 요청도 허용하되, intake와 문서 게이트를 우회할 수는 없다.

## 다음 스텝

- spec 승인 후 `docs/operations/agent-handoff-harness.md` 작성
- `AGENTS.md`에 공통 상태 전이 규칙 반영
- `docs/tasks/` 위임 템플릿 정리
