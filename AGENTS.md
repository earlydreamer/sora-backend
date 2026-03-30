# 에이전트 작업 가이드 — sora-backend

이 저장소에서 Claude와 Codex가 작업할 때 지켜야 하는 정책을 정의한다.
공통 정책 섹션은 sora-frontend의 AGENTS.md와 동일하게 유지한다.

---

## 1. 역할 분리 〔공통〕

| 에이전트 | 담당 |
|---|---|
| **Claude** | 방향 결정, 범위 조정, 아키텍처 검토, 정책 수립, gstack 기획 스킬 실행 |
| **Codex** | 구현, 반복 수정, 테스트 작성, 디버깅, 단순 리팩토링 |

- 결정 권한이 불명확할 때는 Codex가 먼저 Claude에 확인하고 진행한다.
- 마감 단계에서는 `/review`와 `/qa`를 기본 점검 절차로 사용한다.

### 1-1. Claude의 구현 금지 원칙

Claude는 아래 유형의 작업을 **직접 구현하지 않는다**. 반드시 Codex에 위임한다.

- 코드 파일 신규 작성 또는 수정 (문서 파일 제외)
- 버그 수정, 리팩토링, 반복 수정
- gstack 스킬(`/review`, `/qa` 등)이 AUTO-FIX를 제안하더라도 Claude가 직접 적용하지 않는다

**예외**: 정책 파일(AGENTS.md, CLAUDE.md), 문서 파일(docs/), 환경 설정(.env.example 등 비밀 미포함 파일)은 Claude가 직접 작성·수정할 수 있다.

### 1-2. Codex 위임 방식

현재 환경에서 사용 가능한 위임 수단:

| 수단 | 사용 시점 |
|---|---|
| **Claude Code 서브에이전트** (`Agent` 툴) | 세션 내 즉시 위임. Claude가 스펙 작성 후 `general-purpose` 에이전트 실행. |
| **Codex CLI (별도 터미널)** | 세션 외부 위임. Claude가 `docs/tasks/` 스펙 파일 작성 → 사람이 Codex에 전달. |

### 1-3. 위임 스펙 형식

Claude가 Codex에 작업을 넘길 때는 아래 형식으로 작업 범위를 명시한다.

```
## Codex 위임 작업

**목표**: <한 줄 요약>

**수정 대상 파일**:
- `경로/파일.ts` — <무엇을 어떻게 변경할지>

**완료 조건**:
- [ ] 빌드 통과 (`npm run build`)
- [ ] 린트 통과 (`npm run lint`)
- [ ] <기타 검증 기준>

**참고**: <아키텍처 맥락, 주의사항>
```

### 1-4. handoff harness 강제 규칙

- Claude는 `/review` 여부와 관계없이 코드 변경이 필요한 작업을 직접 구현하지 않는다.
- 구현 시작 게이트는 slash command가 아니라 `docs/current.md`의 상태와 `docs/tasks/`의 활성 스펙이다.
- `/start-harness`는 단순 진입 명령이 아니라, 함께 전달된 명령어와 프롬프트를 해석해 지원되는 skill/명령 중 가장 적절한 것을 먼저 선택·트리거하는 오케스트레이터로 동작해야 한다.
- 이때 판단 대상은 superpowers만이 아니라 gstack, 저장소 운영 문서에 정의된 workflow, 기타 현재 환경에서 지원되는 skill/명령 전체를 포함한다.
- Codex는 `codex-ready` 상태의 활성 스펙이 있거나, direct-to-codex intake에서 스스로 `direct-codex-safe`로 분류한 경우에만 구현을 시작한다.
- direct-to-codex 요청도 intake와 문서 게이트를 우회할 수 없다.
- 한 저장소에는 동시에 하나의 활성 구현 스펙만 유지한다.
- 저장소를 넘는 작업은 하나의 통합 스펙으로 처리하지 않고 저장소별 작업으로 분리한다.

---

## 2. 커밋 규칙 〔공통〕

### 2-1. 언어
- 커밋 제목과 본문은 **한국어**로 작성한다.
- Co-authored-by 줄은 넣지 않는다.

### 2-2. 형식
```
<제목> (50자 내외)

- <변경 이유 또는 내용> (bullet, 필요한 경우만)
- <변경 이유 또는 내용>
```
- 제목만으로 의도가 충분히 전달되면 본문 생략 가능.
- 본문은 무엇을 바꿨는지보다 **왜** 바꿨는지 중심으로 작성한다.

### 2-3. 의미 단위 분할 원칙
- **하나의 커밋 = 하나의 의도.** 기능 추가, 버그 수정, 리팩토링, 문서 변경은 각각 별도 커밋.
- 예외: 초기 scaffold처럼 분리가 불가능한 경우에 한해 하나로 묶는다.
- 코드 변경과 문서 변경을 같은 커밋에 넣지 않는다 (scaffold 제외).

### 2-4. 자동화 환경에서의 준수
- Codex가 자율 작업 중에도 위 규칙을 동일하게 적용한다.
- 에이전트가 생성한 커밋이 이 규칙을 위반하면 rebase로 정정한 뒤 push한다.
- 자동화 도중 규칙 위반이 감지되면 작업을 중단하고 Claude에 보고한다.

### 2-5. GitHub Issue 규칙
- 신규 작업은 시작 전에 반드시 한국어 GitHub issue를 생성한다.
- issue 제목은 한 줄 요약으로 작성한다.
- issue 본문은 최소한 `배경`, `목표`, `범위`, `완료 조건` 섹션을 포함한다.
- 완료 조건에는 저장소 필수 검증 명령을 체크리스트로 넣는다.

예시:
```md
## 배경
- handoff harness에 GitHub 작업 파이프라인을 추가해야 한다.

## 목표
- issue 생성 → 브랜치 작업 → PR → merge → 정리 흐름을 문서와 skill에 반영한다.

## 범위
- AGENTS.md
- docs/operations/
- start-harness skill

## 완료 조건
- [ ] `npm run build`
- [ ] `npm run lint`
- [ ] `CI=1 npm test -- --runInBand`
- [ ] `CI=1 npm run test:e2e -- --runInBand`
```

### 2-6. GitHub Pull Request 규칙
- PR 제목과 본문은 한국어로 작성한다.
- PR 본문은 최소한 `요약`, `검증`, `연결 이슈` 섹션을 포함한다.
- `연결 이슈`에는 `Closes #<번호>`를 사용해 merge 시 issue가 자동으로 닫히게 한다.

예시:
```md
## 요약
- GitHub issue/PR 기반 작업 파이프라인을 backend 문서와 skill에 반영했다.

## 검증
- [x] `npm run build`
- [x] `npm run lint`
- [x] `CI=1 npm test -- --runInBand`
- [x] `CI=1 npm run test:e2e -- --runInBand`

## 연결 이슈
- Closes #123
```

### 2-7. 브랜치와 merge 규칙
- 브랜치명은 `codex/<issue-number>-brief-slug` 형식을 사용한다.
- 작업은 issue에 연결된 브랜치에서만 진행한다.
- 검증이 모두 통과하기 전에는 PR merge를 진행하지 않는다.
- merge 완료 후 issue, PR, 로컬 브랜치, 원격 브랜치가 남아 있으면 작업 완료로 간주하지 않는다.
- GitHub 작업 절차 상세는 [docs/operations/github-task-pipeline.md](./docs/operations/github-task-pipeline.md)를 따른다.

---

## 3. 문서 구조 규칙 〔공통〕

### 3-1. 루트 파일
루트에는 아래 파일만 허용한다. 임의 md 파일을 루트에 추가하지 않는다.

| 파일 | 역할 |
|---|---|
| `README.md` | 프로젝트 소개, 개발 환경, 주요 구조 |
| `AGENTS.md` | 에이전트 작업 정책 (이 파일) |
| `CLAUDE.md` | Claude 전용 보조 지시 (필요 시) |

### 3-2. docs/ 디렉터리 구조
```
docs/
  operations/   ← 설치·운영·배포 절차 (영구 문서)
  decisions/    ← 아키텍처·기술 결정 기록 (ADR 형식)
  history/      ← 세션별 작업 기록 (누적)
  tasks/        ← Claude 또는 Codex intake가 만드는 활성 구현 스펙
```

### 3-3. 파일 네이밍
- 파일명은 **영어 kebab-case**로 작성한다. 한글 파일명 금지.
- 날짜 기반 파일: `YYYY-MM-DD-brief-slug.md`
- 영구 운영 문서: 날짜 없이 역할 중심 이름 (예: `gstack-global-setup.md`)

### 3-4. 문서 내용 언어
- 문서 내용은 **한국어**를 우선한다.
- 코드 블록, 명령어, 고유명사(패키지명 등)는 그대로 영어.

---

## 4. 현재 작업 컨텍스트 정책 〔공통〕

### 4-1. 목적
- `docs/current.md`는 **지금 이 저장소가 어떤 상태인지**를 항상 반영하는 단일 파일이다.
- 에이전트 교체·컨텍스트 재시작 시 이 파일 하나로 즉시 작업을 이어받을 수 있어야 한다.
- history(과거 기록)와 분리한다. current는 항상 "지금"만 담는다.

### 4-2. 위치
```
docs/current.md
```

### 4-3. 파일 형식
```md
# 현재 작업 컨텍스트

최종 업데이트: YYYY-MM-DD HH:MM
업데이트 주체: Claude / Codex

## 프로젝트 상태
<현재 단계를 한 줄로> (예: 백엔드 scaffold 완료, DB 연결 대기 중)

## 활성 컨텍스트
<지금 이 시점에서 중요한 결정·제약·전제 조건 요약>

## 하네스 상태
- 상태: <claude-triage / codex-ready / codex-in-progress / needs-claude-decision / done>
- 현재 담당: Claude / Codex / 사람
- 활성 스펙: <docs/tasks/... 또는 없음>
- Claude 재판단 필요: 없음 / 있음

## 작업 체크리스트

### 진행 중
- [ ] <작업> (담당: Claude/Codex)

### 대기 중 (블로커 있음)
- [ ] <작업> — 블로커: <이유>

### 완료
- [x] <작업>
```

### 4-4. 업데이트 규칙
- **작업 시작 시**: 담당 에이전트가 파일을 읽고 컨텍스트를 파악한다.
- **작업 완료 시**: 체크리스트를 갱신하고, 프로젝트 상태 한 줄을 업데이트한 뒤 커밋한다.
- **방향 전환 시**: Claude가 활성 컨텍스트를 업데이트한다.
- current.md 갱신은 별도 커밋으로 분리하지 않고 해당 작업 커밋에 포함한다.

### 4-5. 에이전트 인수인계 절차
새 에이전트(또는 컨텍스트 재시작)가 작업을 이어받을 때:
1. `docs/current.md` 읽기
2. `docs/history/` 최신 파일 읽기 (필요 시)
3. `AGENTS.md` 정책 확인
4. 작업 시작

---

## 5. 작업 히스토리 정책 〔공통〕

### 4-1. 목적
- 세션 단위 작업 기록을 `docs/history/`에 남긴다.
- 에이전트 교체, 컨텍스트 재시작 시 히스토리 파일이 인수인계 역할을 한다.

### 4-2. 생성 시점
다음 중 하나에 해당할 때 히스토리 파일을 생성하거나 갱신한다.
- 기획·설계 단계 완료 (office-hours, eng-review, design-review 등)
- 구현 단위 완료 (모듈 구현, 화면 구현 등)
- 주요 결정 사항 확정 (기술 스택 변경, 정책 수립 등)

### 4-3. 파일 위치와 이름
```
docs/history/YYYY-MM-DD-<slug>.md
예: docs/history/2026-03-30-backend-scaffold.md
```

### 4-4. 파일 형식
```md
# <작업 제목>

날짜: YYYY-MM-DD
작업자: Claude / Codex / 혼합

## 작업 범위
<무엇을 했는지 한 줄 요약>

## 변경 내용
- <항목>

## 결정 사항
- <이번 세션에서 확정된 결정>

## 다음 스텝
- <미완료 항목 또는 이어서 할 것>
```

### 4-5. gstack 프로젝트 파일과의 관계
- `~/.gstack/projects/`의 파일은 **기획·리뷰 단계의 산출물**이다.
- 실행 기록(구현 완료, 결정 확정)은 저장소의 `docs/history/`에 남긴다.
- 중복 기록보다 역할 구분이 중요하다: gstack = 계획, history = 실행 결과.

---

## 6. 자동화 계약 〔공통〕

에이전트가 자율 작업(하네스 모드) 중에도 반드시 지켜야 하는 규칙이다.
이 규칙은 사람의 명시적 지시 없이는 변경할 수 없다.

### 5-1. 절대 금지
- `.env` 파일 커밋
- `node_modules/`, `dist/`, `generated/`, `.next/`, `out/` 커밋
- 아키텍처 변경(모듈 신규 추가, 새 외부 API 연동, DB 스키마 구조 변경)을 Claude 승인 없이 진행
- 커밋 규칙(섹션 2)을 위반한 커밋 생성
- 루트에 임의 md 파일 추가

### 5-2. 커밋 전 필수 확인
- 빌드 또는 타입체크 통과 (`npm run build`)
- 린트 통과 (`npm run lint`)
- 기존 테스트가 있다면 통과 확인

### 5-3. 불확실할 때의 행동 원칙
- 범위가 애매하면 **작게 실행하고 Claude에 보고**한다.
- 삭제·덮어쓰기보다 추가를 우선한다.
- 확신 없는 아키텍처 결정은 TODO 주석으로 표시하고 멈춘다.

### 5-4. 리뷰 루프 제한
- 같은 파일 또는 같은 task에서 reviewer 수정 루프는 최대 2회까지만 반복한다.
- 2회 이후 남는 피드백은 `blocking`과 `non-blocking`으로 나눈다.
- `blocking`은 계약 위반, 잘못된 상태 전이, 안전 문제, 실행 불가 상태처럼 결과를 깨는 항목만 포함한다.
- `non-blocking`은 표현 개선, 추가 명확화, 스타일 선호, 확장 제안처럼 당장 실행을 막지 않는 항목이다.
- 2회 이후에는 `blocking`만 한 번 더 수정하고, `non-blocking`은 후속 작업이나 기록으로 넘긴 뒤 다음 단계로 진행한다.
- 같은 지점에서 30분 이상 정체되면 controller가 루프를 종료하고 현재 최선 버전을 커밋하거나 후속 작업으로 분리한다.

### 5-5. 리뷰 시 환경 차이 무시 규칙
- Windows와 Linux/Unix 간 기본 인코딩, 개행 문자(CRLF/LF), chmod/실행 비트 차이처럼 운영체제 환경 차이에서만 발생하는 변경은 리뷰 지적 대상에서 제외한다.
- 리뷰는 실제 코드 경로, 런타임 동작, 타입/빌드/테스트 결과, API 계약처럼 **의미 있는 코드 변경**에만 집중한다.
- 인코딩 또는 줄바꿈 차이가 실제 파싱 오류, 빌드 실패, 런타임 오류를 일으킬 때만 예외적으로 다룬다.

---

## 7. gstack 운영 원칙 〔공통〕

- 전역 설치 기준 경로: `~/.claude/skills/gstack`
- repo-local skill 설치 금지
- 설치·업그레이드 절차: [docs/operations/gstack-global-setup.md](./docs/operations/gstack-global-setup.md)

---

## 8. 백엔드 저장소 전용 규칙

### 기술 제약
- TMAP API 키는 절대 프론트엔드에 노출하지 않는다. 서버사이드 프록시만 허용.
- Prisma schema 변경 시 반드시 `npx prisma migrate dev`로 migration 생성 후 커밋.
- `generated/prisma/`는 `.gitignore`에 포함되어 있으며 커밋하지 않는다.

### 모듈 구조 원칙
- 신규 기능은 반드시 별도 NestJS 모듈로 분리한다.
- 모듈 간 의존성은 `imports` 배열로만 표현하고, 직접 인스턴스화하지 않는다.
- 전역으로 사용하는 서비스(Prisma)는 `@Global()` 모듈로만 공유한다.

### 연관 저장소
- 프론트엔드: [earlydreamer/sora-frontend](https://github.com/earlydreamer/sora-frontend)
