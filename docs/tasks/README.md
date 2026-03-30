# docs/tasks 사용 규칙

## 목적

이 디렉터리는 Claude가 Codex에게 넘기는 구현 스펙과, direct-to-codex intake에서 Codex가 스스로 만드는 intake spec을 저장한다.

## 기본 규칙

- 활성 구현 스펙은 저장소당 하나만 유지한다.
- 파일명은 `YYYY-MM-DD-brief-slug.md` 형식을 사용한다.
- `docs/current.md`의 `활성 스펙` 경로와 실제 파일이 일치해야 한다.
- 구현이 끝났거나 중단되면 `docs/current.md` 상태를 먼저 갱신한다.

## 작성 주체

- 일반 handoff: Claude가 작성
- direct-to-codex safe intake: Codex가 작성

## 저장소 경계

- 하나의 스펙은 하나의 저장소만 담당한다.
- 다른 저장소 변경이 필요하면 후속 작업으로 분리한다.

## 템플릿

- 새 작업은 `docs/tasks/codex-work-item-template.md`를 기준으로 작성한다.
