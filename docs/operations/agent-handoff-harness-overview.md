# 에이전트 handoff harness 개요

이 문서는 사람이 Claude-Codex handoff 구조를 빠르게 이해하기 위한 참고 문서다. 실제 강제 규칙과 상태 정의의 진실 원천은 [2026-03-30-agent-handoff-harness-design.md](/mnt/d/Projects/sora/sora-backend/docs/superpowers/specs/2026-03-30-agent-handoff-harness-design.md)이다.

## 한 줄 요약

- Claude는 무엇을 해야 하는지 정리한다.
- Codex는 어떻게 구현할지 실행한다.
- 둘의 접점은 slash command가 아니라 `codex-ready` 상태와 활성 작업 문서다.

## 전체 흐름 개요

```mermaid
flowchart TD
    A["새 요청 수신"] --> B{"어느 에이전트로 먼저 들어왔는가?"}
    B -->|Claude| C["Claude triage"]
    B -->|Codex| D["Codex direct intake"]

    C --> E{"코드 변경이 필요한가?"}
    E -->|아니오| F["Claude docs-only 처리"] --> Z["done"]
    E -->|예| G["Claude handoff spec 작성"]
    G --> H["codex-ready"]

    D --> I{"기존 활성 작업이 있는가?"}
    I -->|예| J["기존 spec 재개"] --> K["codex-in-progress"]
    I -->|아니오| L{"direct-codex-safe 인가?"}
    L -->|예| M["Codex가 intake spec 작성"] --> H
    L -->|아니오| N["needs-claude-decision"]

    H --> K["codex-in-progress"]
    K --> O{"구현 중 판단 경계가 생겼는가?"}
    O -->|예| N["needs-claude-decision"]
    O -->|아니오| P["codex-reviewing"]
    P --> Q{"검증 통과?"}
    Q -->|예| Z["done"]
    Q -->|아니오| K

    N --> R["Claude 재판단"]
    R --> G
```

## 역할 분리 요약

```mermaid
flowchart LR
    A["Claude"] --> A1["요청 triage"]
    A --> A2["gstack review 해석"]
    A --> A3["설계/범위 판단"]
    A --> A4["Codex 위임 spec 작성"]

    B["Codex"] --> B1["활성 spec 읽기"]
    B --> B2["구현"]
    B --> B3["superpowers 기반 작업 분해"]
    B --> B4["검증 / review / QA"]

    C["Claude 재호출"] --> C1["DB 스키마 변경"]
    C --> C2["외부 API 계약 변경"]
    C --> C3["아키텍처 경계 변경"]
    C --> C4["범위 확장"]
```

## direct-to-codex 요청의 안전장치

```mermaid
flowchart TD
    A["사용자가 Codex에게 직접 요청"] --> B["AGENTS.md / docs/current.md / 활성 spec 확인"]
    B --> C{"활성 spec 존재?"}
    C -->|예| D["기존 작업 재개"]
    C -->|아니오| E{"safe direct 구현 조건 충족?"}
    E -->|예| F["Codex가 intake spec 먼저 작성"]
    F --> G["docs/current.md 를 codex-ready로 갱신"]
    G --> H["구현 시작"]
    E -->|아니오| I["needs-claude-decision 기록 후 중단"]
```

## 사람이 읽는 포인트

- `/review`는 중요하지만 유일한 시작점은 아니다. 구현 요청은 모두 결국 `codex-ready` 산출물 게이트를 통과해야 한다.
- direct-to-codex 요청도 바로 구현으로 가지 않고, 먼저 intake와 문서 게이트를 거친다.
- `docs/current.md`는 현재 활성 상태를, `docs/tasks/*.md`는 실제 작업 계약을 나타낸다.
- 문서 충돌이나 저장소 경계 문제가 생기면 구현보다 상태 정규화와 재판단이 먼저다.

## 추천 읽기 순서

1. 이 문서로 전체 구조를 빠르게 훑는다.
2. [2026-03-30-agent-handoff-harness-design.md](/mnt/d/Projects/sora/sora-backend/docs/superpowers/specs/2026-03-30-agent-handoff-harness-design.md)에서 강제 규칙과 예외를 확인한다.
3. [AGENTS.md](/mnt/d/Projects/sora/sora-backend/AGENTS.md)에서 저장소별 규칙을 본다.
