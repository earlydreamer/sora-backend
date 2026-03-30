# handoff harness 운영 문서 롤아웃

날짜: 2026-03-31
작업자: Codex

## 작업 범위

handoff harness spec을 실제 운영 문서, AGENTS 규칙, task 템플릿, current 상태 형식으로 backend 저장소에 반영했다.

## 변경 내용

- `docs/operations/agent-handoff-harness.md` 추가
- `AGENTS.md`에 handoff harness 게이트 반영
- `docs/tasks/` 템플릿과 README 추가
- `docs/current.md`에 하네스 상태 섹션 추가
- 같은 파일에서 무한 리뷰가 반복되지 않도록 review budget과 exit rule 추가

## 결정 사항

- 구현 시작 게이트는 활성 스펙과 `docs/current.md` 상태다.
- direct-to-codex 요청도 intake와 문서 게이트를 우회할 수 없다.
- reviewer 수정 루프는 최대 2회까지 반복하고, 이후에는 blocking 이슈만 추가 수정한다.
- frontend 저장소 반영은 별도 후속 작업으로 분리한다.

## 다음 스텝

- frontend 저장소에 같은 문서 계약 이식
- 필요하면 파일 큐 또는 CLI 래퍼 자동화 검토
