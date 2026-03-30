# GitHub 작업 파이프라인 추가

날짜: 2026-03-31
작업자: Codex

## 작업 범위

backend 저장소에 GitHub issue 생성, 작업 브랜치, pull request, merge, 정리까지 포함한 신규 작업 파이프라인을 추가했다.

## 변경 내용

- `docs/operations/github-task-pipeline.md` 추가
- `AGENTS.md`에 GitHub issue/PR/브랜치 규칙 추가
- `start-harness` skill에 GitHub issue/branch/PR/cleanup 절차 반영
- `docs/current.md`에 GitHub 파이프라인 반영 상태 기록

## 결정 사항

- 기본 GitHub 툴체인은 `gh` CLI를 사용한다.
- 신규 작업은 시작 전에 한국어 issue를 먼저 만든다.
- 작업 브랜치는 `codex/<issue-number>-brief-slug` 형식을 사용한다.
- 검증 통과 전에는 PR merge를 진행하지 않는다.
- merge 뒤 issue, PR, 브랜치가 남아 있으면 작업 완료가 아니다.

## 다음 스텝

- frontend 저장소에도 같은 GitHub 작업 파이프라인을 동기화
- 실제 첫 구현 작업에서 `/start-harness`로 issue 생성부터 merge/cleanup까지 검증
