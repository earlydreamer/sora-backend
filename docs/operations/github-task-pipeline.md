# GitHub 작업 파이프라인

## 목적

이 문서는 `sora-backend` 저장소에서 신규 작업을 GitHub issue, 브랜치, pull request, merge, 정리까지 일관된 절차로 처리하는 방법을 정의한다.

## 기본 툴체인

- 기본 GitHub 연동 도구는 `gh` CLI를 사용한다.
- 시작 전에 `gh auth status`가 성공해야 한다.
- 원격 저장소는 `origin`을 기준으로 한다.

## 작업 시작 절차

1. `main` 기준 최신 상태를 확인한다.
2. 한국어 GitHub issue를 생성한다.
3. issue 번호를 기준으로 작업 브랜치를 만든다.
4. 필요하면 `.worktrees/` 아래에서 브랜치를 분리해 작업한다.
5. handoff harness를 쓰는 작업이면 `docs/current.md`와 `docs/tasks/`를 먼저 갱신한다.

## Issue 규칙

- 코드나 문서를 실제로 변경하는 신규 작업은 시작 전에 issue를 먼저 만든다.
- issue 제목과 본문은 한국어로 작성한다.
- 제목은 한 줄 요약으로 쓴다.
- 본문에는 최소한 아래 항목을 넣는다.
- `docs-only` 작업이면 완료 조건을 문서 무결성 확인 항목으로 바꿀 수 있다.

```md
## 배경
- <왜 필요한지>

## 목표
- <무엇을 끝낼지>

## 범위
- <이번 작업에 포함할 것>

## 완료 조건
- [ ] `npm run build`
- [ ] `npm run lint`
- [ ] `CI=1 npm test -- --runInBand`
- [ ] `CI=1 npm run test:e2e -- --runInBand`
```

## 브랜치 규칙

- 브랜치명은 `codex/<issue-number>-brief-slug` 형식을 사용한다.
- 작업은 반드시 issue에 연결된 브랜치에서만 진행한다.
- 구현 완료 후 merge되면 로컬/원격 브랜치를 모두 정리한다.

## 구현 및 검증

- 구현 중 커밋 메시지는 `AGENTS.md`의 한국어 규칙을 따른다.
- 작업 완료 전 아래 검증을 다시 실행한다.

```bash
npm run build
npx eslint "{src,apps,libs,test}/**/*.ts"
CI=1 npm test -- --runInBand
CI=1 npm run test:e2e -- --runInBand
```

- 위 검증이 실패하면 merge를 진행하지 않는다.

### `docs-only` 예외

- `docs-only` 작업은 `build/lint/test`를 필수 검증으로 강제하지 않는다.
- 대신 아래 항목으로 검증을 대체한다.

```bash
rg -n "<핵심 키워드>" docs/<target>.md
git diff -- docs/<target>.md
```

- 확인 기준은 다음과 같다.
  - 문서 링크와 경로가 실제 파일과 일치한다.
  - 관련 운영 문서 사이에 규칙 충돌이 없다.
  - `docs/current.md`나 `docs/history/` 갱신이 필요하면 함께 반영돼 있다.
- `docs-only` PR 본문에는 검증 섹션에 문서 무결성 확인 결과를 적고, `build/lint/test`는 생략하거나 비대상으로 명시한다.

## Pull Request 규칙

- PR은 한국어 제목과 본문을 사용한다.
- PR 제목은 issue 제목을 기반으로 한 한 줄 요약으로 쓴다.
- PR 본문에는 최소한 아래 항목을 넣는다.

```md
## 요약
- <무엇을 바꿨는지>

## 검증
- [x] `npm run build`
- [x] `npm run lint`
- [x] `CI=1 npm test -- --runInBand`
- [x] `CI=1 npm run test:e2e -- --runInBand`

## 연결 이슈
- Closes #<issue-number>
```

## Merge 및 정리

1. 검증 통과 후 PR을 `main`에 merge한다.
   `docs-only` 작업은 문서 무결성 확인 완료를 검증 통과로 본다.
   기본 merge 전략은 non-squash다.
2. merge 뒤 PR이 `merged` 상태인지 확인한다.
3. issue가 닫혔는지 확인한다. 자동으로 닫히지 않았다면 즉시 닫는다.
4. 로컬 브랜치와 원격 브랜치를 삭제한다.
5. issue, PR, 브랜치가 하나라도 남아 있으면 작업 완료로 간주하지 않는다.

### 히스토리 가시성 원칙

- Fork 같은 GUI Git 클라이언트에서 `main` 히스토리를 눈으로 따라갈 수 있어야 한다.
- 따라서 의미 단위 커밋이 `main`에서 바로 보이도록 squash merge를 기본값으로 사용하지 않는다.
- 기본 전략은 `merge`이며, 저장소 정책이나 사용자 요청이 따로 있을 때만 다른 전략을 쓴다.
- squash는 사용자가 명시적으로 요청했거나, fixup-only 브랜치를 하나로 접는 것이 더 적절한 예외 상황에서만 사용한다.

## 권장 명령 예시

```bash
gh auth status
gh issue create
git switch main
git pull --ff-only origin main
git switch -c codex/<issue-number>-brief-slug
gh pr create
gh pr merge --merge --delete-branch
gh issue close <issue-number>
git branch -d codex/<issue-number>-brief-slug
```
