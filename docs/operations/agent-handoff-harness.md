# 에이전트 handoff harness 운영 절차

## 목적

이 문서는 `sora-backend` 저장소에서 Claude와 Codex가 어떤 문서와 상태를 기준으로 작업을 넘겨야 하는지 정리한다. 개요와 도식은 `docs/operations/agent-handoff-harness-overview.md`를 보고, 강제 규칙의 진실 원천은 `docs/superpowers/specs/2026-03-30-agent-handoff-harness-design.md`를 따른다.

`AGENTS.md`의 일반 인수인계 절차는 baseline으로 유지하되, handoff 판단과 상태 기록은 이 문서의 절차와 구조를 우선 적용한다. 필요하면 `docs/history/`의 최신 기록도 함께 확인한다.

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

이 절차는 `docs/tasks/`와 `docs/current.md`의 `## 하네스 상태` 섹션을 공식 운영 구조로 사용한다. 따라서 이 문서는 해당 구조를 기준으로 handoff를 판단한다.
`docs/current.md`의 `## 하네스 상태`는 기존 형식에 추가되는 섹션이며, 기존 섹션을 대체하지 않는다.
bootstrap 시점에는 먼저 `docs/tasks/` 디렉터리와 `docs/current.md`의 `## 하네스 상태` 섹션을 만든 뒤 이 절차를 적용한다. 코드 변경이 필요한 첫 작업이면 첫 작업 스펙 파일도 함께 만든다. `docs-only` bootstrap이면 작업 스펙 없이 문서 작업만 처리한다.

## 기본 원칙

- 구현 시작 게이트는 slash command가 아니라 `docs/current.md`의 상태와 `docs/tasks/`의 활성 작업 문서다.
- `/start-harness`는 일반 triage 래퍼가 아니라 오케스트레이터다. 명령어와 프롬프트를 함께 읽고, 지원되는 skill/명령 중 가장 적절한 흐름을 먼저 선택한 뒤 하네스 상태 갱신으로 이어가야 한다.
- 이 오케스트레이션은 superpowers, gstack, 저장소 운영 문서에 적힌 workflow, 기타 현재 환경에서 사용 가능한 skill/명령 전체를 함께 비교해 결정한다.
- Claude는 코드 변경이 필요한 요청에서 직접 구현하지 않는다.
- Codex는 활성 작업 문서 없이 구현을 시작하지 않는다.
- 이 문서에서 말하는 작업 스펙, 활성 작업 문서, work spec, intake spec은 모두 `docs/tasks/YYYY-MM-DD-<slug>.md` 형식의 같은 운영 산출물을 뜻한다.
- direct-to-codex 요청도 intake와 문서 작성 단계를 거쳐야 한다. 다만 `docs-only`는 활성 구현 스펙이 없을 때만 작업 스펙 없이 처리하는 예외다.
- `docs-only` 요청은 활성 구현 스펙이 없을 때만 문서 작업으로 처리하며, 수정 대상 문서를 갱신한 뒤 `docs/current.md`를 `done`, 현재 담당을 사람으로 설정하고 종료한다. `docs/history/`는 실행 결과가 영구 기록일 때만 갱신한다.
- `docs-only` 요청은 `build/lint/test`를 필수 검증으로 요구하지 않는다. 대신 문서 링크, 경로, 참조 문서 정합성 확인으로 마감한다.
- 활성 구현 스펙이 이미 있으면 `docs-only`를 별도 흐름으로 열지 않고, 현재 활성 작업 범위 안에서 문서 갱신 여부를 판단한다.
- 한 저장소에는 동시에 하나의 활성 구현 작업만 유지한다.

## Claude 절차

### 1. 요청 분류

- 문서 전용이고 활성 구현 스펙이 없으면 Claude가 직접 처리한다.
- 코드 변경이 필요하면 Claude가 먼저 `docs/current.md`를 `claude-triage`로 기록하고 현재 담당을 Claude로 둔다. 새 작업이면 즉시 작업 스펙을 만든 뒤 `**상태**`를 `claude-triage`로 맞추고, 그 단계에서 handoff drafting을 수행한다.
- 아키텍처나 범위 판단이 필요하면 Claude가 관련 review 흐름을 먼저 수행한다.

### 2. 위임 스펙 작성

- 새 작업이면 `docs/tasks/YYYY-MM-DD-<slug>.md`를 만든다.
- 기존 작업 후속이면 기존 활성 작업 문서를 갱신한다.
- `**상태**`, 완료 조건, 수정 대상 파일, Claude 재호출 조건을 반드시 채운다.

### 3. 상태판 갱신

`docs/current.md`의 `하네스 상태` 섹션을 아래 형식으로 맞춘다.

```md
## 하네스 상태
- 상태: codex-ready
- 현재 담당: Claude
- 활성 스펙: docs/tasks/YYYY-MM-DD-<slug>.md
- Claude 재판단 필요: 없음
```

Claude가 handoff 스펙을 완성하면 작업 스펙의 `**상태**`와 `docs/current.md`를 함께 `codex-ready`로 바꾸고, 현재 담당은 Claude로 둔다. direct-codex-safe에서는 Codex가 같은 `codex-ready`를 직접 만들 수 있고, 이 경우 현재 담당도 Codex로 둔다. `codex-ready`는 구현 직전 상태를 뜻하고, 실제 구현을 시작하면 항상 현재 담당을 Codex로 바꾸고 상태를 `codex-in-progress`로 갱신한다.

이 문서에서 쓰는 작업 상태는 `claude-triage`, `codex-ready`, `codex-in-progress`, `needs-claude-decision`, `done`이다. `정규화`는 작업 스펙의 `**상태**`와 경로에 맞춰 `docs/current.md`의 상태와 활성 스펙 경로를 일치시키고, 현재 담당은 이 문서의 상태-담당자 규칙으로 계산하는 것을 뜻한다.
`Claude 재판단 필요`는 `needs-claude-decision`일 때만 `있음`으로 두고, 나머지 상태에서는 `없음`으로 유지한다.

## Codex 절차

### 1. direct-to-codex가 아닌 일반 handoff

- `docs/current.md`가 `codex-ready`이고 활성 스펙이 존재하면 해당 스펙을 읽고 구현을 시작한다.
- Codex가 실제 구현을 시작하는 순간 work spec의 `**상태**`와 `docs/current.md`를 `codex-in-progress`로 갱신하고 현재 담당을 Codex로 맞춘다.
- 구현 중에는 필요하면 계획을 더 잘게 나누고 subagent를 사용할 수 있다.
- 검증 전 완료로 간주하지 않는다.

### 2. direct-to-codex 요청

- 먼저 `AGENTS.md`, `docs/current.md`, 기존 활성 스펙을 읽는다.
- 프롬프트에 명시된 slash command, review/qa/debugging 의도, gstack workflow, 기타 명확한 specialist skill 후보를 먼저 분류한다.
- 더 구체적인 skill/명령이 있으면 generic intake 전에 그 흐름을 먼저 트리거한다. 여러 후보가 맞으면 최소 체인으로 연결하고, 독립 분석 축이 있으면 subagent 사용도 적극 검토한다.
- 기존 활성 스펙이 있고 `docs/current.md`가 `codex-ready` 또는 `codex-in-progress`처럼 재개 가능한 상태이며, 작업 스펙에 `**상태**`, 수정 대상 파일, 완료 조건, Claude 재호출 조건이 모두 있으면 그 작업을 재개한다.
- 재개 가능한 상태여도 작업 스펙 필수 필드가 비어 있거나 불완전하면 `needs-claude-decision`으로 정리하고 멈춘다.
- 그 외 상태라면 작업 스펙의 `**상태**`와 경로를 첫 번째 기준으로 `docs/current.md`를 정규화한다. 담당자 규칙은 `claude-triage`, `needs-claude-decision`이면 Claude, `codex-in-progress`면 Codex, `done`이면 사람이다. `codex-ready`는 생성 경로를 따라 일반 handoff면 Claude, direct-codex-safe면 Codex로 둔다. 스펙이 없거나 불완전하면 `needs-claude-decision`으로 두고 멈춘다.
- 정규화 결과가 `codex-ready` 또는 `codex-in-progress`면 Codex가 즉시 재개하고, `done`이면 활성 스펙을 비우고 종료하며, `needs-claude-decision`이면 그대로 멈춘다.
- 기존 활성 스펙이 없으면 요청을 `docs-only`, `direct-codex-safe`, `needs-claude-decision`으로 분류한다.
- `docs-only`면 수정 대상 문서를 갱신하고 `docs/current.md`를 `done`, 현재 담당을 사람으로 설정한 뒤 종료한다.
- `direct-codex-safe`인 경우에만 Codex가 직접 작업 스펙을 만들고 `codex-ready`, 현재 담당을 Codex로 맞춘 뒤, 구현 시작 시 `codex-in-progress`로 갱신하고 진행한다.
- `needs-claude-decision`이면 작업 스펙을 남기거나 갱신하고 `**상태**`를 `needs-claude-decision`으로 맞춘 뒤, blocker를 함께 남긴다. `docs/current.md`도 같은 상태와 활성 스펙으로 맞추고 현재 담당은 Claude로 둔다.

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
- 활성 스펙 경로가 틀렸다면 `docs/tasks/` 안에서 `**상태**`가 `done`이 아닌 작업 스펙을 먼저 찾고, 그 후보가 하나면 그 파일을 권위 있는 활성 스펙으로 사용한다. 후보가 없거나 둘 이상이면 `needs-claude-decision`으로 두고 멈춘다.
- 작업 스펙의 `**상태**` 필드와 `docs/current.md`의 상태가 다르면 먼저 둘을 일치시킨다.
- 이 절차에서 말하는 정규화는 작업 스펙의 `**상태**`와 경로에 맞춰 `docs/current.md`의 상태와 활성 스펙 경로를 맞추고, 현재 담당은 상태-담당자 규칙으로 다시 계산하는 작업이다.
- 저장소를 넘는 작업이 필요하면 현재 저장소 스펙에서 범위를 끊고 후속 작업으로 분리한다.

## 마감

- 구현을 끝낸 에이전트는 검증 명령을 다시 실행한다.
- `docs-only` 작업이면 위 검증 명령 대신 문서 무결성 확인 결과를 남긴다.
- work spec의 `**상태**`와 `docs/current.md`를 `done`으로 갱신하고 현재 담당을 사람으로 맞춘 뒤, `docs/current.md`의 활성 스펙을 비운다.
- 필요한 경우 `docs/history/`에 실행 결과를 남긴다.
