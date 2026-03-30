# Claude-Codex handoff harness 설계

작성일: 2026-03-30
프로젝트: `sora-backend`, `sora-frontend` 공통 운영 규칙
상태: 대화에서 방향 합의 완료, 최종 spec 검토 대기

## 요약

`gstack`과 `superpowers`를 함께 쓰되, Claude와 Codex가 서로 다른 CLI라는 현실을 전제로 공통 하네스 계약을 문서로 고정한다. 핵심은 `/review` 자체가 아니라 Claude가 남기는 `codex-ready` 산출물을 Codex 실행의 유일한 시작 신호로 삼는 것이다. 이 계약은 두 저장소 모두에 동일하게 적용하되, 각 저장소는 혼자 로컬에 있어도 문서만 읽으면 완결된 흐름을 재현할 수 있어야 한다.

## 목표

- Claude는 판단, 범위 조정, 리뷰 해석, 위임 스펙 작성만 담당하고 구현은 하지 않는 흐름을 강제한다.
- Codex는 `codex-ready` 상태의 작업만 이어받아 구현하고, 필요하면 superpowers 기반으로 하위 작업을 분해한다.
- `/review`를 거친 후속 수정뿐 아니라 일반 구현 요청, 설계 승인 후 구현, 미완료 작업 재개도 하나의 상태 머신으로 흡수한다.
- 백엔드와 프론트엔드가 별도 저장소여도 같은 계약으로 동작하게 한다.
- 둘 중 하나의 저장소만 로컬에 있어도 하네스 규칙이 깨지지 않게 한다.

## 비목표

- Claude CLI와 Codex CLI를 직접 연결하는 실시간 IPC를 이번 범위에 포함하지 않는다.
- 지금 단계에서 스크립트 오케스트레이터, 파일 큐, daemon을 바로 구현하지 않는다.
- 두 저장소를 하나의 monorepo나 공유 설정 저장소로 합치지 않는다.
- `gstack`과 `superpowers`의 내부 구현을 수정하지 않는다.

## 문제 배경

현재 운영 원칙은 문서상으로는 Claude가 설계와 리뷰 해석을 맡고 Codex가 구현을 맡도록 정의되어 있다. 하지만 실제 작업에서는 `/review` 이후 적절한 상태 전이와 트리거가 없어서 Claude가 곧바로 코드 수정을 계속하는 경우가 생긴다. 이 때문에 Claude 사용량이 구현 단계까지 확장되고, 원래 의도한 "토큰이 비싼 판단은 Claude, 반복 구현은 Codex" 구조가 실제 실행에서는 보장되지 않는다.

또한 모든 구현 요청이 `/review`를 거치고 들어오는 것은 아니다. 일반 기능 추가 요청, 설계 승인 이후 구현 요청, 이전 작업 재개, 문서만 수정하는 요청처럼 진입점이 다양하다. 따라서 하네스의 시작 조건을 특정 slash command가 아니라 상태와 산출물 기준으로 잡아야 한다.

## 결정

공통 계약은 `명령 기반`이 아니라 `상태 + 산출물 기반`으로 설계한다. Claude가 리뷰 결과나 사용자 요청을 해석해 구현이 필요하다고 판단하면, 직접 코드를 수정하지 않고 `Codex 위임 작업` 형식의 문서를 작성한다. 이 문서가 생성되고 `docs/current.md`에 현재 상태가 `codex-ready`로 반영될 때만 Codex가 구현을 시작할 수 있다.

`/review`는 `codex-ready` 상태를 만드는 여러 입력 중 하나다. 즉, review를 거치지 않은 요청이라도 Claude가 triage 후 충분한 구현 맥락을 정리해 `codex-ready` 산출물을 만들면 Codex가 바로 이어받을 수 있어야 한다.

## 공통 상태 머신

### 상태 목록

- `intake-open`: 아직 어떤 에이전트가 맡을지 정해지지 않은 입력 상태
- `claude-triage`: Claude가 요청의 성격을 분류하고 구현 필요 여부를 판단하는 상태
- `claude-docs-only`: 코드 변경 없이 문서나 정책만 수정하면 되는 상태
- `claude-handoff-drafting`: Claude가 Codex 위임 스펙을 작성하는 상태
- `codex-ready`: Codex가 실행할 수 있는 산출물이 준비된 상태
- `codex-in-progress`: Codex가 구현 중인 상태
- `codex-reviewing`: Codex가 review, verification, QA를 수행하는 상태
- `needs-claude-decision`: Codex가 결정 경계를 만나 Claude 재판단이 필요한 상태
- `done`: 해당 작업이 완료된 상태

### 기본 전이

| 현재 상태 | 트리거 | 다음 상태 |
|---|---|---|
| `intake-open` | 새 요청 수신 | `claude-triage` |
| `claude-triage` | 코드 변경 불필요 | `claude-docs-only` |
| `claude-triage` | 코드 변경 필요, 방향 명확 | `claude-handoff-drafting` |
| `claude-triage` | 아키텍처/범위 판단 필요 | Claude 설계 절차 유지 |
| `claude-handoff-drafting` | 위임 스펙과 상태판 갱신 완료 | `codex-ready` |
| `codex-ready` | Codex 실행 시작 | `codex-in-progress` |
| `codex-in-progress` | 구현 완료 후 검증 시작 | `codex-reviewing` |
| `codex-in-progress` | 결정 경계 도달 | `needs-claude-decision` |
| `codex-reviewing` | 검증 통과 | `done` |
| `codex-reviewing` | 리뷰 후속 수정 필요 | `codex-in-progress` |
| `needs-claude-decision` | Claude 재판단 완료 | `claude-handoff-drafting` 또는 `done` |

## 진입점별 처리 규칙

### 1. `/review` 후속 수정

- Claude가 `/review` 결과를 읽고 actionable code change가 하나라도 있다고 판단하면 직접 수정하지 않는다.
- Claude는 리뷰 지적 사항을 정리한 뒤 `Codex 위임 작업` 문서를 작성한다.
- `docs/current.md`에 활성 스펙 경로와 상태를 `codex-ready`로 갱신한다.
- 그 후 구현 주체는 Codex로 전환된다.

### 2. 일반 구현 요청

- 사용자가 단순히 "기능 추가", "버그 수정", "리팩토링"을 요청해도 Claude는 먼저 `claude-triage`를 수행한다.
- 방향과 범위가 이미 충분히 명확하면 review를 생략할 수 있다.
- 이 경우에도 Claude는 직접 코드를 수정하지 않고 얇은 위임 스펙을 작성한 뒤 `codex-ready`로 전환한다.

### 3. 설계 승인 후 구현 요청

- `gstack`의 `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`로 방향이 정리된 작업은 Claude가 설계 승인 상태를 명시한다.
- 설계가 승인되면 Claude는 구현 스펙을 작성하고 `codex-ready` 상태를 만든다.
- Codex는 이 스펙을 바탕으로 구현을 시작한다.

### 4. 문서 전용 요청

- 코드 변경이 필요 없는 문서, 정책, 운영 메모 수정은 Claude가 직접 처리할 수 있다.
- 이 경우 Codex로 전환하지 않으며 `claude-docs-only -> done`으로 끝난다.

### 5. 미완료 작업 재개

- 이전에 생성된 활성 작업 스펙이 있고 `docs/current.md`에 상태가 `codex-ready` 또는 `codex-in-progress`로 남아 있으면, Codex는 같은 스펙을 읽고 재개할 수 있다.
- 이 재개 흐름은 review 명령 이력에 의존하지 않는다.

## 산출물 계약

### Codex 실행 게이트

Codex의 구현 시작 조건은 다음 두 항목이 모두 만족되는 경우다.

1. 활성 작업 문서가 존재한다.
2. `docs/current.md`에 현재 상태가 `codex-ready`로 기록되어 있다.

즉, `gstack /review`가 실행되었더라도 위 두 조건이 없으면 Codex는 구현을 시작하면 안 된다.

### 위임 스펙 위치

```text
docs/tasks/YYYY-MM-DD-<slug>.md
```

### 위임 스펙 최소 필드

```md
## Codex 위임 작업

**상태**: codex-ready
**출처**: <review 후속 / 일반 구현 요청 / 설계 승인 후 구현 / 작업 재개>
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
- [ ] <리뷰 지적 사항 반영 등 도메인 조건>

**Claude 재호출 조건**:
- <새 모듈 추가 여부>
- <DB 스키마 변경 여부>
- <외부 API 계약 변경 여부>

**참고**:
- <관련 spec, review 결과, 제약>
```

### 상태판 필드

`docs/current.md`에는 아래 필드를 추가할 수 있어야 한다.

```md
## 하네스 상태
- 상태: codex-ready
- 현재 담당: Claude / Codex
- 활성 스펙: docs/tasks/2026-03-30-sample.md
- Claude 재판단 필요: 없음 / 있음
```

이 섹션은 두 저장소 모두 같은 형식으로 유지하고, 저장소별 예외는 `AGENTS.md`에 둔다.

## Claude 규칙

### 공통 금지

- Claude는 코드 파일 신규 작성이나 수정을 직접 하지 않는다.
- `/review` 결과에 code change가 필요하면 직접 fix를 적용하지 않는다.
- Codex 위임 스펙 없이 "구현하라"는 식의 자유형 후속 지시만 남기지 않는다.

### 허용 작업

- 요청 분류와 triage
- `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/review` 실행 및 결과 해석
- `docs/tasks/*.md` 위임 스펙 작성
- `docs/current.md` 상태 갱신
- 문서와 정책 파일 수정

## Codex 규칙

### 시작 조건

- `codex-ready` 상태의 활성 스펙이 있는 경우에만 구현을 시작한다.
- 단순히 "이전 Claude 세션을 이어서 하자"는 문장만으로는 구현을 시작하지 않는다.
- 먼저 `AGENTS.md`, `docs/current.md`, 활성 작업 스펙을 읽어야 한다.

### 실행 원칙

- 구현은 superpowers 흐름을 따른다.
- 설계가 이미 승인된 작업은 필요 시 `writing-plans`로 구현 계획을 더 잘게 쪼갠 뒤 진행한다.
- 하위 작업이 2개 이상으로 자연스럽게 분해되면 `subagent-driven-development`를 사용한다.
- 검증 전 완료 주장 금지 원칙은 `verification-before-completion`을 따른다.

### 중단 조건

아래 상황이 나오면 Codex는 스스로 결정하지 않고 `needs-claude-decision`으로 전환해야 한다.

- 아키텍처 경계가 바뀌는 경우
- DB 스키마 변경이 필요한 경우
- 외부 API 계약 변경이 필요한 경우
- 새 전역 모듈 또는 새로운 공용 패턴 도입이 필요한 경우
- 기존 위임 스펙의 범위를 벗어나는 확장이 필요한 경우

## gstack과 superpowers의 역할 매핑

### Claude 단계에서 주로 쓰는 도구

- `gstack /office-hours`
- `gstack /plan-ceo-review`
- `gstack /plan-eng-review`
- `gstack /review`

이 단계의 목적은 구현이 아니라 판단, 범위 수렴, 리뷰 결과 해석, 위임 스펙 작성이다.

### Codex 단계에서 주로 쓰는 도구

- `writing-plans`
- `subagent-driven-development`
- `verification-before-completion`
- 필요 시 `systematic-debugging`, `test-driven-development`

이 단계의 목적은 이미 승인된 범위 안에서 구현을 빠르게 분해하고 검증까지 끝내는 것이다.

### 시너지 원칙

- `gstack`은 생각과 검토의 흐름을 책임진다.
- `superpowers`는 구현 분해와 검증의 흐름을 책임진다.
- 둘의 접점은 `/review` 명령 그 자체가 아니라 Claude가 남기는 `codex-ready` 위임 산출물이다.

## 저장소별 예외 레이어

### 공통 원칙

- 상태 머신, 위임 산출물 형식, Codex 시작 조건은 두 저장소에서 동일하게 유지한다.
- 저장소별 차이는 `AGENTS.md` 하단의 예외 섹션에서만 관리한다.

### 백엔드 저장소 예외

- DB 스키마 변경
- 새 NestJS 모듈 추가
- 외부 API 계약 변경
- 배포 런타임 영향이 있는 선택

위 항목은 Claude 재호출 조건으로 기본 포함한다.

### 프론트엔드 저장소 예외

- 라우팅 구조 변경
- 디자인 시스템 규칙 변경
- 공용 상태 관리 방식 변경
- 핵심 UX 흐름 재정의

위 항목은 프론트엔드 저장소의 `AGENTS.md`에 예외로 반영한다.

## 권장 문서 배치

- `AGENTS.md`: 가장 짧은 강제 규칙과 저장소별 예외
- `docs/operations/agent-handoff-harness.md`: 상태 머신과 트리거 설명
- `docs/tasks/`: Claude가 생성하는 Codex 위임 스펙
- `docs/current.md`: 현재 상태와 활성 스펙 기록

중앙 문서 하나에만 의존하는 방식은 채택하지 않는다. 각 저장소가 혼자 로컬에 있어도 같은 계약을 스스로 제공해야 하기 때문이다.

## 롤아웃 단계

### 1단계: 문서 계약 고정

- 두 저장소의 `AGENTS.md`에 공통 상태 전이 규칙과 저장소별 예외를 반영한다.
- `docs/operations/agent-handoff-harness.md`를 각 저장소에 둔다.
- `docs/tasks/` 디렉터리를 공식 위임 위치로 문서화한다.

### 2단계: 템플릿과 체크리스트 정리

- `Codex 위임 작업` 템플릿을 만든다.
- `docs/current.md`의 하네스 상태 필드를 정착시킨다.
- review 후속, 일반 구현 요청, 설계 승인 후 구현의 예시를 각 저장소에 한 개씩 남긴다.

### 3단계: 선택적 자동화

- 필요하면 파일 큐나 CLI 래퍼를 붙여 `codex-ready` 상태를 읽고 Codex CLI를 자동 실행한다.
- 다만 자동화는 문서 계약이 두 저장소에서 안정화된 뒤에만 도입한다.

## 리스크와 대응

### 리스크: 상태 이름만 늘고 실제로는 우회 실행됨

대응: Codex의 시작 조건을 명령 이력 대신 활성 스펙과 `docs/current.md` 상태로 제한한다.

### 리스크: review를 거치지 않은 요청이 흐름 밖으로 빠짐

대응: `/review`를 특수 케이스가 아니라 여러 진입점 중 하나로 정의한다.

### 리스크: 두 저장소 규칙이 시간이 지나며 드리프트함

대응: 공통 상태 전이와 위임 형식은 동일 문장으로 유지하고, 차이는 저장소별 예외 섹션으로만 한정한다.

### 리스크: Codex가 판단 경계를 넘어서 구현을 계속함

대응: `needs-claude-decision` 상태를 명시하고, 재호출 조건을 위임 스펙 필수 필드로 강제한다.

## 성공 기준

- `/review` 이후 Claude가 바로 구현하는 흐름이 문서상 금지되고, 실제 기본 행동이 위임 스펙 작성으로 바뀐다.
- review를 거치지 않은 구현 요청도 같은 상태 머신으로 `codex-ready`까지 전이할 수 있다.
- Codex는 활성 위임 스펙이 없는 한 구현을 시작하지 않는다.
- 백엔드와 프론트엔드 중 하나의 저장소만 로컬에 있어도 같은 문서 계약을 재현할 수 있다.
- 향후 자동화 스크립트를 붙이더라도 계약 변경 없이 읽기만 하면 되는 수준의 산출물 구조가 준비된다.

## 다음 단계

이 spec이 승인되면 다음 구현 순서로 간다.

1. `docs/operations/agent-handoff-harness.md` 작성
2. `AGENTS.md`에 공통 상태 전이 규칙과 저장소별 예외 연결
3. `docs/tasks/` 템플릿 정의
4. 필요 시 프론트엔드 저장소에 같은 문서 계약 이식
