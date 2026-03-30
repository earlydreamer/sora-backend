# 에이전트 handoff harness 롤아웃 구현 계획

> **에이전트 작업자용:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans`를 사용해 이 계획을 작업 단위로 실행한다. 진행 추적은 체크박스(`- [ ]`) 문법을 사용한다.

**목표:** 승인된 Claude-Codex handoff harness 계약을 이 backend 저장소의 운영 문서, AGENTS 규칙, task 템플릿, current 상태 형식으로 실제 반영한다.

**아키텍처:** spec를 규칙의 진실 원천으로 두고, 사람용 개요 문서는 분리 유지한다. backend 저장소 안에는 실제 운영 절차 문서 1개를 추가하고, `AGENTS.md`에 hard gate를 반영하며, `docs/tasks/` 산출물과 `docs/current.md`의 하네스 상태 섹션을 만들어 다음 세션도 추측 없이 이어받을 수 있게 한다. 이 계획은 의도적으로 backend 로컬 범위만 다루며, frontend 저장소 반영은 해당 저장소가 준비된 뒤 별도 계획으로 분리한다.

**기술 스택:** Markdown, git, ripgrep, 기존 gstack 문서, 기존 superpowers 문서

---

## 파일 구조 및 책임

- Create: `docs/operations/agent-handoff-harness.md`
  - Backend repository용 실제 운영 절차 문서. Claude와 Codex가 어떤 순서로 문서를 읽고 상태를 바꿔야 하는지 기록한다.
- Modify: `AGENTS.md`
  - 저장소 전체 강제 규칙에 handoff harness 게이트를 반영한다. `docs/tasks/`를 공식 구조에 추가하고, direct-to-codex 규칙도 넣는다.
- Create: `docs/tasks/README.md`
  - `docs/tasks/` 디렉터리의 naming, active task 규칙, 작성 주체, 저장소 경계를 설명한다.
- Create: `docs/tasks/codex-work-item-template.md`
  - Claude 또는 Codex direct intake가 사용할 표준 `Codex 위임 작업` 템플릿을 제공한다.
- Modify: `docs/current.md`
  - 하네스 상태 섹션을 추가해 현재 상태, 담당 에이전트, 활성 스펙, Claude 재판단 필요 여부를 기록한다.
- Create: `docs/history/2026-03-31-agent-handoff-harness-rollout.md`
  - 이번 rollout 실행 결과를 히스토리로 남긴다.

## 범위 메모

- 이 계획은 `sora-backend` 저장소 하나에서 끝나는 롤아웃만 다룬다.
- `sora-frontend` 반영은 이 저장소에서 문서 계약이 실제로 안정화된 뒤 별도 계획으로 분리한다.
- 자동 실행 스크립트, 파일 큐, daemon은 이 계획 범위에 넣지 않는다.

### Task 1: 운영 절차 문서 추가

**Files:**
- Create: `docs/operations/agent-handoff-harness.md`
- Reference: `docs/operations/agent-handoff-harness-overview.md`
- Reference: `docs/superpowers/specs/2026-03-30-agent-handoff-harness-design.md`
- Test: `docs/operations/agent-handoff-harness.md`

- [ ] **Step 1: 운영 절차 문서가 아직 없는지 확인**

```bash
test -f docs/operations/agent-handoff-harness.md && echo "UNEXPECTED_DOC_EXISTS" || echo "DOC_MISSING"
```

Expected: `DOC_MISSING`

- [ ] **Step 2: 운영 절차 문서를 작성**

새 파일 `docs/operations/agent-handoff-harness.md`에 아래 내용을 그대로 작성한다.

```md
# 에이전트 handoff harness 운영 절차

## 목적

이 문서는 `sora-backend` 저장소에서 Claude와 Codex가 어떤 문서와 상태를 기준으로 작업을 넘겨야 하는지 정리한다. 개요와 도식은 `docs/operations/agent-handoff-harness-overview.md`를 보고, 강제 규칙의 진실 원천은 `docs/superpowers/specs/2026-03-30-agent-handoff-harness-design.md`를 따른다.

## 읽기 순서

### Claude가 먼저 읽을 문서

1. `AGENTS.md`
2. `docs/current.md`
3. 관련 spec 또는 review 결과
4. `docs/tasks/`의 기존 활성 작업 문서 (있다면)

### Codex가 먼저 읽을 문서

1. `AGENTS.md`
2. `docs/current.md`
3. `docs/tasks/`의 활성 작업 문서
4. 관련 spec 또는 review 결과

## 기본 원칙

- 구현 시작 게이트는 slash command가 아니라 `docs/current.md`의 상태와 `docs/tasks/`의 활성 작업 문서다.
- Claude는 코드 변경이 필요한 요청에서 직접 구현하지 않는다.
- Codex는 활성 작업 문서 없이 구현을 시작하지 않는다.
- direct-to-codex 요청도 intake와 문서 작성 단계를 거쳐야 한다.
- 한 저장소에는 동시에 하나의 활성 구현 작업만 유지한다.

## Claude 절차

### 1. 요청 분류

- 문서 전용이면 Claude가 직접 처리한다.
- 코드 변경이 필요하면 `claude-handoff-drafting`으로 들어간다.
- 아키텍처나 범위 판단이 필요하면 Claude가 관련 review 흐름을 먼저 수행한다.

### 2. 위임 스펙 작성

- 새 작업이면 `docs/tasks/YYYY-MM-DD-<slug>.md`를 만든다.
- 기존 작업 후속이면 기존 활성 작업 문서를 갱신한다.
- 완료 조건, 수정 대상 파일, Claude 재호출 조건을 반드시 채운다.

### 3. 상태판 갱신

`docs/current.md`의 `하네스 상태` 섹션을 아래 형식으로 맞춘다.

```md
## 하네스 상태
- 상태: codex-ready
- 현재 담당: Claude
- 활성 스펙: docs/tasks/YYYY-MM-DD-<slug>.md
- Claude 재판단 필요: 없음
```

## Codex 절차

### 1. direct-to-codex가 아닌 일반 handoff

- `docs/current.md`가 `codex-ready`이고 활성 스펙이 존재하면 해당 스펙을 읽고 구현을 시작한다.
- 구현 중에는 필요하면 계획을 더 잘게 나누고 subagent를 사용할 수 있다.
- 검증 전 완료로 간주하지 않는다.

### 2. direct-to-codex 요청

- 먼저 `AGENTS.md`, `docs/current.md`, 기존 활성 스펙을 읽는다.
- 기존 활성 스펙이 있으면 그 작업을 재개한다.
- 기존 활성 스펙이 없으면 요청을 `docs-only`, `direct-codex-safe`, `needs-claude-decision`으로 분류한다.
- `direct-codex-safe`인 경우에만 Codex가 직접 intake spec을 만들고 `codex-ready`로 상태를 바꾼 뒤 구현한다.
- 나머지는 `needs-claude-decision`으로 남기고 중단한다.

## direct-codex-safe 기준

- 기존 파일 또는 기존 모듈 안에서 끝나는 좁은 수정
- DB 스키마 변경 없음
- 외부 API 계약 변경 없음
- 전역 구조 변경 없음
- 저장소 하나에서 끝남
- 로컬 검증 명령으로 완료를 확인할 수 있음

하나라도 애매하면 Claude 재판단으로 돌린다.

## 충돌 처리

- `docs/current.md`에 적힌 활성 스펙 경로와 실제 파일이 다르면 구현보다 문서 정규화가 먼저다.
- `docs/current.md` 상태와 스펙 문서의 상태가 다르면 먼저 둘을 일치시킨다.
- 저장소를 넘는 작업이 필요하면 현재 저장소 스펙에서 범위를 끊고 후속 작업으로 분리한다.

## 마감

- 구현을 끝낸 에이전트는 검증 명령을 다시 실행한다.
- `docs/current.md`의 상태를 최종 상태로 갱신한다.
- 필요한 경우 `docs/history/`에 실행 결과를 남긴다.
```

- [ ] **Step 3: 운영 문서 핵심 문구를 검증**

```bash
rg -n "구현 시작 게이트|direct-to-codex|하네스 상태|충돌 처리" docs/operations/agent-handoff-harness.md
```

Expected: 게이트, direct-to-codex, 상태판, 충돌 처리 관련 줄이 출력된다.

- [ ] **Step 4: 운영 절차 문서만 커밋**

```bash
git add docs/operations/agent-handoff-harness.md
git commit -m "handoff harness 운영 절차 문서 추가" -m " - backend 저장소에서 Claude와 Codex가 읽어야 할 문서와 상태 전이 순서를 운영 절차로 정리함
 - direct-to-codex intake와 충돌 처리 규칙을 실제 실행 관점으로 풀어 적음"
```

Expected: 운영 문서만 포함한 한국어 커밋 1개가 생성된다.

### Task 2: AGENTS 규칙에 handoff harness 게이트 반영

**Files:**
- Modify: `AGENTS.md`
- Test: `AGENTS.md`

- [ ] **Step 1: `AGENTS.md`에서 수정할 위치를 확인**

```bash
rg -n "### 1-3\\. 위임 스펙 형식|### 3-2\\. docs/ 디렉터리 구조|### 4-3\\. 파일 형식" AGENTS.md
```

Expected: 위임 스펙, docs 구조, current 형식 관련 줄 번호가 출력된다.

- [ ] **Step 2: `docs/` 구조 정의에 `tasks/`를 추가**

`AGENTS.md`의 `### 3-2. docs/ 디렉터리 구조` 블록을 아래 내용으로 교체한다.

```md
### 3-2. docs/ 디렉터리 구조
```
```text
docs/
  operations/   ← 설치·운영·배포 절차 (영구 문서)
  decisions/    ← 아키텍처·기술 결정 기록 (ADR 형식)
  history/      ← 세션별 작업 기록 (누적)
  tasks/        ← Claude 또는 Codex intake가 만드는 활성 구현 스펙
```

- [ ] **Step 3: 역할 분리 섹션 아래에 handoff harness 강제 규칙을 추가**

`### 1-3. 위임 스펙 형식` 아래에 다음 섹션을 그대로 추가한다.

```md
### 1-4. handoff harness 강제 규칙

- Claude는 `/review` 여부와 관계없이 코드 변경이 필요한 작업을 직접 구현하지 않는다.
- 구현 시작 게이트는 slash command가 아니라 `docs/current.md`의 상태와 `docs/tasks/`의 활성 스펙이다.
- Codex는 `codex-ready` 상태의 활성 스펙이 있거나, direct-to-codex intake에서 스스로 `direct-codex-safe`로 분류한 경우에만 구현을 시작한다.
- direct-to-codex 요청도 intake와 문서 게이트를 우회할 수 없다.
- 한 저장소에는 동시에 하나의 활성 구현 스펙만 유지한다.
- 저장소를 넘는 작업은 하나의 통합 스펙으로 처리하지 않고 저장소별 작업으로 분리한다.
```

- [ ] **Step 4: `docs/current.md` 형식에 하네스 상태 섹션을 추가**

`### 4-3. 파일 형식` 예시에 아래 블록을 `## 활성 컨텍스트` 아래, `## 작업 체크리스트` 위에 넣는다.

```md
## 하네스 상태
- 상태: <intake-open / claude-triage / codex-ready / codex-in-progress / needs-claude-decision / done>
- 현재 담당: Claude / Codex / 사람
- 활성 스펙: <docs/tasks/... 또는 없음>
- Claude 재판단 필요: 없음 / 있음
```

- [ ] **Step 5: 변경 내용이 들어갔는지 검증**

```bash
rg -n "tasks/|handoff harness 강제 규칙|codex-ready|활성 스펙" AGENTS.md
```

Expected: `tasks/`, handoff harness 규칙, `codex-ready`, 활성 스펙 관련 줄이 모두 출력된다.

- [ ] **Step 6: `AGENTS.md` 변경만 커밋**

```bash
git add AGENTS.md
git commit -m "AGENTS에 handoff harness 게이트 반영" -m " - Claude 직접 구현 금지와 Codex 실행 게이트를 AGENTS 규칙으로 고정함
 - docs/tasks 구조와 current의 하네스 상태 형식을 공식 문서 구조에 추가함"
```

Expected: `AGENTS.md`만 포함한 한국어 커밋 1개가 생성된다.

### Task 3: `docs/tasks/` 템플릿과 사용 규칙 추가

**Files:**
- Create: `docs/tasks/README.md`
- Create: `docs/tasks/codex-work-item-template.md`
- Test: `docs/tasks/README.md`
- Test: `docs/tasks/codex-work-item-template.md`

- [ ] **Step 1: `docs/tasks/`가 비어 있는지 확인**

```bash
test -d docs/tasks || echo "TASKS_DIR_MISSING"
find docs/tasks -maxdepth 2 -type f | sed -n '1,20p'
```

Expected: 처음 실행에서는 `TASKS_DIR_MISSING`가 출력되거나, 출력 파일이 없어 빈 상태임을 확인한다.

- [ ] **Step 2: `docs/tasks/README.md`를 작성**

새 파일 `docs/tasks/README.md`에 아래 내용을 그대로 작성한다.

```md
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
```

- [ ] **Step 3: `docs/tasks/codex-work-item-template.md`를 작성**

새 파일 `docs/tasks/codex-work-item-template.md`에 아래 내용을 그대로 작성한다.

```md
# Codex 위임 작업 템플릿

## Codex 위임 작업

**상태**: codex-ready
**출처**: <review 후속 / 일반 구현 요청 / 설계 승인 후 구현 / 작업 재개 / direct-to-codex intake>
**목표**: <한 줄 요약>

**배경**:
- <왜 이 작업이 필요한지>

**수정 대상 파일**:
- `path/to/file.ts` — <무엇을 어떻게 바꿀지>

**비범위**:
- <이번 작업에 포함하지 않을 것>

**완료 조건**:
- [ ] `npm run build`
- [ ] `npm run lint`
- [ ] <필요한 테스트 명령>
- [ ] <도메인별 완료 조건>

**Claude 재호출 조건**:
- <아키텍처 경계 변경 여부>
- <DB 스키마 변경 여부>
- <외부 API 계약 변경 여부>
- <범위 확장 여부>

**참고**:
- <관련 spec, review 결과, 제약>
```

- [ ] **Step 4: 템플릿과 README를 검증**

```bash
rg -n "활성 구현 스펙|direct-to-codex|저장소 경계" docs/tasks/README.md
rg -n "\\*\\*상태\\*\\*|\\*\\*완료 조건\\*\\*|\\*\\*Claude 재호출 조건\\*\\*" docs/tasks/codex-work-item-template.md
```

Expected: README에서 활성 스펙 규칙과 direct-to-codex 문구가, 템플릿에서 상태/완료 조건/재호출 조건 필드가 출력된다.

- [ ] **Step 5: `docs/tasks/` 문서만 커밋**

```bash
git add docs/tasks/README.md docs/tasks/codex-work-item-template.md
git commit -m "docs/tasks handoff 템플릿 추가" -m " - Claude handoff와 direct-to-codex intake가 공통으로 쓰는 작업 템플릿을 추가함
 - 활성 스펙, 저장소 경계, 작성 주체 규칙을 README로 정리함"
```

Expected: `docs/tasks/` 문서만 포함한 한국어 커밋 1개가 생성된다.

### Task 4: `docs/current.md` 하네스 상태와 rollout 히스토리 반영

**Files:**
- Modify: `docs/current.md`
- Create: `docs/history/2026-03-31-agent-handoff-harness-rollout.md`
- Test: `docs/current.md`

- [ ] **Step 1: 현재 `docs/current.md`에 하네스 상태 섹션이 없는지 확인**

```bash
rg -n "^## 하네스 상태$|활성 스펙|Claude 재판단 필요" docs/current.md
```

Expected: 실행 전에는 결과가 없거나, 아직 공식 형식으로 정리되지 않은 상태임을 확인한다.

- [ ] **Step 2: `docs/current.md`에 하네스 상태 섹션을 추가**

`docs/current.md`의 `## 활성 컨텍스트` 바로 아래에 다음 블록을 추가하고, 현재 상태는 문서 작업 완료 기준으로 아래 값으로 맞춘다.

```md
## 하네스 상태
- 상태: done
- 현재 담당: 사람
- 활성 스펙: 없음
- Claude 재판단 필요: 없음
```

- [ ] **Step 3: rollout 히스토리 파일을 작성**

새 파일 `docs/history/2026-03-31-agent-handoff-harness-rollout.md`에 아래 내용을 그대로 작성한다.

```md
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

## 결정 사항

- 구현 시작 게이트는 활성 스펙과 `docs/current.md` 상태다.
- direct-to-codex 요청도 intake와 문서 게이트를 우회할 수 없다.
- frontend 저장소 반영은 별도 후속 작업으로 분리한다.

## 다음 스텝

- frontend 저장소에 같은 문서 계약 이식
- 필요하면 파일 큐 또는 CLI 래퍼 자동화 검토
```

- [ ] **Step 4: 문서 반영 결과를 검증**

```bash
rg -n "^## 하네스 상태$|활성 스펙|Claude 재판단 필요" docs/current.md
rg -n "운영 문서 롤아웃|direct-to-codex|frontend 저장소 반영" docs/history/2026-03-31-agent-handoff-harness-rollout.md
```

Expected: current에서 하네스 상태 블록이, history에서 rollout 요약과 후속 항목이 출력된다.

- [ ] **Step 5: 전체 저장소 검증을 실행**

```bash
npm run build
npx eslint "{src,apps,libs,test}/**/*.ts"
CI=1 npm test -- --runInBand
CI=1 npm run test:e2e -- --runInBand
```

Expected: 네 명령이 모두 성공 종료한다.

- [ ] **Step 6: current와 history 반영을 커밋**

```bash
git add docs/current.md docs/history/2026-03-31-agent-handoff-harness-rollout.md
git commit -m "handoff harness 상태판과 이력 반영" -m " - current에 하네스 상태 섹션을 추가해 활성 스펙과 담당 상태를 기록할 수 있게 함
 - backend 저장소 기준 rollout 결과를 history 문서로 남김"
```

Expected: current와 history만 포함한 한국어 커밋 1개가 생성된다.

## 자체 점검

- Spec coverage:
  - 운영 절차 문서 추가: Task 1
  - AGENTS 강제 규칙 반영: Task 2
  - `docs/tasks/` 템플릿 정의: Task 3
  - `docs/current.md` 상태 형식 반영: Task 4
  - direct-to-codex 대응: Task 1, Task 2, Task 3
  - frontend 적용은 별도 저장소 작업이므로 이 계획에서는 의도적으로 제외
- Placeholder scan:
  - `TBD`, `TODO`, "적절히", "나중에" 같은 문구 없이 실제 문서 내용과 명령을 모두 적었다.
- Type consistency:
  - 상태 이름은 `codex-ready`, `codex-in-progress`, `needs-claude-decision`, `done`으로 spec과 맞췄다.
  - 문서 경로는 `docs/tasks/...`, `docs/current.md`, `docs/operations/...`로 통일했다.
