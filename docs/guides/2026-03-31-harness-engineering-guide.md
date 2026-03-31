# sora-backend 하네스 엔지니어링 가이드

> **버전**: 2026-03-31
> **대상**: Claude, Codex, 사람 (프로젝트 참여자 전원)
> **목적**: 이 저장소에서 에이전트와 사람이 협업하는 구조 전체를 한 문서에서 파악한다.

---

## 목차

1. [하네스란 무엇인가](#1-하네스란-무엇인가)
2. [전체 아키텍처](#2-전체-아키텍처)
3. [계층 구조](#3-계층-구조)
4. [에이전트 역할 분리](#4-에이전트-역할-분리)
5. [하네스 상태 기계](#5-하네스-상태-기계)
6. [문서 체계](#6-문서-체계)
7. [GitHub 작업 파이프라인](#7-github-작업-파이프라인)
8. [tmux 병렬 워커 오케스트레이션](#8-tmux-병렬-워커-오케스트레이션)
9. [Orchestrator 스크립트 레퍼런스](#9-orchestrator-스크립트-레퍼런스)
10. [환경 감지 (probe.sh)](#10-환경-감지-probesh)
11. [운영 체크리스트](#11-운영-체크리스트)

---

## 1. 하네스란 무엇인가

**하네스(harness)**는 Claude와 Codex가 서로를 교체하거나 이어받을 때 작업이 끊기지 않도록 하는 운영 계약이다.

단순한 폴더 구조나 문서 규칙이 아니라, 다음 세 가지를 동시에 보장하는 시스템이다.

| 보장 항목 | 수단 |
|---|---|
| **인수인계 안전성** | `docs/current.md` + `docs/tasks/` 상태 기계 |
| **역할 경계 강제** | `AGENTS.md` 정책 + `/start-harness` 오케스트레이터 |
| **병렬 실행 가시성** | tmux `.orchestrator/` 런타임 상태 + helper scripts |

> 핵심 원칙: 다음 에이전트가 같은 로컬 경로를 열었을 때 즉시 이어받을 수 있어야 작업이 완료된 것이다.

---

## 2. 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                         사람 (Human)                            │
│         방향 결정 · 외부 리소스 준비 · 최종 승인               │
└──────────────────────────┬──────────────────────────────────────┘
                           │ /start-harness <명령>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Claude (오케스트레이터)                        │
│  - 요청 분류 및 흐름 선택 (gstack / superpowers / tmux / 직접)  │
│  - 작업 스펙 작성 (docs/tasks/)                                 │
│  - GitHub 이슈 생성 및 상태 관리                                │
│  - 코드 직접 구현 금지 (문서/정책 파일 제외)                    │
└──────────┬───────────────────────────────────┬──────────────────┘
           │ spawn-worker --auto-start         │ Agent 툴 (fallback)
           ▼                                   ▼
┌──────────────────────┐         ┌─────────────────────────────┐
│  tmux 워커 (Codex /  │         │  Claude Code 서브에이전트   │
│  Claude CLI 프로세스) │         │  (general-purpose Agent)    │
│                      │         │                             │
│  scripts/orchestrator│         │  tmux 없을 때 마지막 수단   │
│  .orchestrator/ JSON │         └─────────────────────────────┘
└──────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   GitHub 파이프라인                              │
│  issue → codex/<번호>-slug 브랜치 → PR (한국어) → merge → 정리 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. 계층 구조

에이전트가 작업을 위임할 때는 아래 우선순위를 따른다.

```
우선순위 1 ─── tmux spawn-worker
               ↓ HAS_TMUX_ORCHESTRATION=1 일 때 최우선
               ↓ 실제 Codex/Claude CLI 프로세스를 tmux window에서 실행
               ↓ .orchestrator/ JSON으로 상태 추적

우선순위 2 ─── codex-plugin-cc (/codex:rescue)
               ↓ HAS_CODEX_PLUGIN=1 이고 tmux 세션 없을 때
               ↓ 로컬 codex 바이너리를 app server 모드로 실행
               ↓ Claude 토큰 미소비

우선순위 3 ─── Claude Code 서브에이전트 (Agent 툴)
               ↓ tmux도 없고 HAS_CODEX_PLUGIN=0 일 때만
               ↓ general-purpose 에이전트

우선순위 4 ─── Codex CLI (별도 터미널)
               ↓ 세션 외부 위임
               ↓ 사람이 docs/tasks/ 스펙을 Codex에 직접 전달
```

> **왜 이 순서인가**: 토큰이 비싼 Claude 판단은 Claude가, 반복 구현은 실제 CLI 프로세스가 담당한다. Agent 툴은 tmux도 플러그인도 없는 절대 fallback이다.

---

## 4. 에이전트 역할 분리

### Claude가 하는 일

| 담당 | 구체적 행동 |
|---|---|
| 방향 결정 | 요청 분류, 흐름 선택, 범위 조정 |
| 스펙 작성 | `docs/tasks/YYYY-MM-DD-<slug>.md` 생성 |
| 상태 관리 | `docs/current.md` 갱신, GitHub 이슈/PR 생성 |
| 리뷰 | `/review`, `/qa`, `/plan-eng-review` 등 gstack 실행 |
| 정책 파일 수정 | `AGENTS.md`, `CLAUDE.md`, `docs/` 직접 작성 가능 |

### Claude가 하지 않는 일 (Codex에 위임)

- 소스 코드 파일 신규 작성 또는 수정
- 버그 수정, 리팩토링, 반복 수정
- gstack AUTO-FIX 직접 적용

### Codex가 하는 일

| 담당 | 구체적 행동 |
|---|---|
| 구현 | 활성 스펙(`docs/tasks/`)을 읽고 코드 작성 |
| 반복 수정 | 리뷰 피드백 반영, 버그 수정 |
| 테스트 | 단위 테스트 작성 및 실행 |
| 커밋 | `AGENTS.md` 한국어 커밋 규칙 준수 |

### Codex가 시작하려면

```
활성 스펙(docs/tasks/) 파일 존재
  + docs/current.md 상태가 codex-ready 또는 codex-in-progress
  = 구현 시작 가능
```

---

## 5. 하네스 상태 기계

`docs/current.md`의 `## 하네스 상태` 섹션이 현재 위치를 나타낸다.

```
         사람/Claude 요청
               │
               ▼
    ┌──────────────────────┐
    │    claude-triage     │  ← Claude가 요청 분류 중
    └──────────┬───────────┘
               │ 스펙 완성
               ▼
    ┌──────────────────────┐
    │     codex-ready      │  ← 스펙 완성, Codex 대기 중
    └──────────┬───────────┘
               │ 구현 시작
               ▼
    ┌──────────────────────┐
    │  codex-in-progress   │  ← Codex 구현 중
    └──────────┬───────────┘
               │ 검증 통과 + PR merge
               ▼
    ┌──────────────────────┐
    │         done         │  ← 완료 (활성 스펙 비움)
    └──────────────────────┘

    언제든지 → needs-claude-decision (블로커 발생 시)
```

### 상태별 담당자

| 상태 | 담당 | 설명 |
|---|---|---|
| `claude-triage` | Claude | 요청 분류 및 스펙 초안 작성 중 |
| `codex-ready` | Claude (일반) / Codex (direct) | 스펙 완성, 구현 대기 |
| `codex-in-progress` | Codex | 실제 구현 진행 중 |
| `needs-claude-decision` | Claude | 블로커 발생, Claude 판단 필요 |
| `done` | 사람 | 완료, 다음 작업 대기 |
| `worker-dispatch-ready` | Claude | tmux 병렬 워커 파견 준비 완료 |

---

## 6. 문서 체계

```
sora-backend/
├── AGENTS.md                    ← 에이전트 작업 정책 (진실 원천)
├── CLAUDE.md                    ← Claude 전용 보조 지시
│
└── docs/
    ├── current.md               ← 현재 작업 상태 (항상 "지금"만 담음)
    │
    ├── operations/              ← 설치·운영·배포 절차 (영구 문서)
    │   ├── agent-handoff-harness.md      ← 하네스 운영 절차
    │   ├── agent-handoff-harness-overview.md
    │   ├── github-task-pipeline.md       ← GitHub 파이프라인 규칙
    │   ├── tmux-orchestration.md         ← tmux 오케스트레이션 가이드
    │   └── gstack-global-setup.md
    │
    ├── guides/                  ← 인간 친화적 개요 가이드 (이 파일)
    │   └── 2026-03-31-harness-engineering-guide.md
    │
    ├── tasks/                   ← 활성 구현 스펙 (Claude/Codex intake)
    │   └── YYYY-MM-DD-<slug>.md
    │
    ├── history/                 ← 세션별 작업 기록 (누적)
    │   └── YYYY-MM-DD-<slug>.md
    │
    ├── decisions/               ← 아키텍처·기술 결정 기록 (ADR)
    └── superpowers/             ← gstack 계획 산출물
        └── plans/
```

### 핵심 파일 역할

| 파일 | 누가 쓰는가 | 무엇을 담는가 |
|---|---|---|
| `AGENTS.md` | 사람 | 전체 에이전트 정책 (브랜치, 커밋, 역할 등) |
| `docs/current.md` | Claude/Codex | 지금 이 순간의 상태 스냅샷 |
| `docs/tasks/*.md` | Claude | Codex에게 넘기는 구현 스펙 |
| `docs/history/*.md` | Claude/Codex | 완료된 작업의 영구 기록 |
| `.orchestrator/state.json` | Helper scripts | tmux 런타임 상태 (커밋 안 함) |

---

## 7. GitHub 작업 파이프라인

모든 신규 작업은 이 흐름을 따른다.

```
1. GitHub 이슈 생성 (한국어)
   gh issue create --title "..." --body "..."

2. 작업 브랜치 생성
   git switch -c codex/<issue-number>-brief-slug

3. 구현 (Codex 또는 Claude)
   - docs/tasks/ 스펙 작성 (코드 변경 시)
   - docs/current.md 갱신

4. 검증
   npm run build
   npx eslint "{src,apps,libs,test}/**/*.ts"
   CI=1 npm test -- --runInBand
   CI=1 npm run test:e2e -- --runInBand
   (* docs-only는 문서 무결성 확인으로 대체)

5. PR 생성 (한국어)
   gh pr create --title "..." --body "..."
   본문에 "Closes #<번호>" 포함

6. merge 후 정리
   - 이슈 닫힘 확인
   - 로컬/원격 브랜치 삭제
   - git switch main && git pull
```

### 커밋 메시지 규칙

```
<한국어 제목> (50자 내외)

- 왜 바꿨는지 중심으로 bullet 작성
- Co-authored-by 줄 넣지 않음
- fix(type): 같은 prefix 없이 바로 한국어 제목
```

---

## 8. tmux 병렬 워커 오케스트레이션

### 전체 구조

```
WSL2 Ubuntu
└── tmux session: sora-backend
    ├── control              ← Claude (오케스트레이터)
    ├── worker-001-codex-auth   ← Codex CLI 프로세스
    ├── worker-002-codex-routes ← Codex CLI 프로세스
    └── worker-003-claude-test  ← Claude CLI 프로세스

scripts/orchestrator/
├── lib.sh          ← 공통 함수 (세션 관리, 큐, JSON 유효성 검사)
├── spawn-worker    ← 워커 생성 + tmux window 열기
├── list-workers    ← 전체 워커 상태 조회
├── capture-worker  ← 특정 워커 최근 출력 캡처
├── mark-worker     ← 워커 상태 수동 업데이트
├── recover-session ← 상태 불일치 감지 및 복구
├── dashboard       ← TUI 상태판
└── enqueue-worker  ← 우선순위 큐에 태스크 추가

.orchestrator/
├── state.json       ← 세션 전체 상태 (git 추적 안 함)
├── workers/
│   └── worker-001.json  ← 워커별 상태
├── logs/
│   └── worker-001.log
└── queue.json       ← 우선순위 큐
```

### 워커 상태 전이

```
starting → running → done
                  ↘ failed  → (retry 가능) → retrying → running
                  ↘ blocked
                  ↘ stale   (tmux window 없어짐)
```

### 병렬 실행 흐름 (`worker-dispatch-ready` 상태일 때)

```
1. docs/current.md 에서 활성 워커 수 확인
2. list-workers --json 으로 현재 워커 상태 조회
3. 누락된 워커가 있으면 spawn-worker --auto-start 로 보충
4. 30초마다 모니터링 루프:
   - failed/blocked → capture-worker 로 진단 → Claude 판단 요청
   - done → 계속
   - running/starting → 계속
5. 전체 done 확인 → recover-session --auto-fix → docs/current.md done 갱신
```

---

## 9. Orchestrator 스크립트 레퍼런스

### spawn-worker

```bash
# 기본: 워커 생성만
scripts/orchestrator/spawn-worker codex auth task-1

# 자동 시작: window 생성 후 CLI 명령 자동 주입
scripts/orchestrator/spawn-worker codex auth task-1 \
  --spec docs/tasks/2026-03-31-auth.md \
  --auto-start

# 커스텀 명령
scripts/orchestrator/spawn-worker codex auth auth-impl \
  --command "npm run build && npm run lint"

# 로그 분할 pane + 자동 재시도
scripts/orchestrator/spawn-worker codex routes task-1 \
  --split-log --retry 3

# 큐에서 꺼내서 실행
scripts/orchestrator/spawn-worker --from-queue
```

**인수 순서**: `<agent> <slug> <task-ref>` (positional, named flag 아님)

| 옵션 | 설명 |
|---|---|
| `--spec FILE` | 작업 스펙 파일 경로 |
| `--auto-start` | agent별 CLI 명령 자동 주입 |
| `--command CMD` | 직접 명령 지정 |
| `--split-log` | window를 main 70% + log 30%로 분할 |
| `--retry N` | 실패 시 최대 N회 자동 재시도 |
| `--from-queue` | queue.json에서 다음 항목 꺼내서 실행 |

### list-workers

```bash
scripts/orchestrator/list-workers          # 인간 친화적 출력
scripts/orchestrator/list-workers --json   # JSON 출력 (자동화용)
```

### capture-worker

```bash
scripts/orchestrator/capture-worker worker-001           # 기본 50줄
scripts/orchestrator/capture-worker worker-001 --lines 100
```

### mark-worker

```bash
scripts/orchestrator/mark-worker worker-001 running
scripts/orchestrator/mark-worker worker-001 done
scripts/orchestrator/mark-worker worker-001 blocked "DB 연결 필요"
scripts/orchestrator/mark-worker worker-001 failed "타임아웃"
```

### recover-session

```bash
scripts/orchestrator/recover-session            # 상태 확인만
scripts/orchestrator/recover-session --auto-fix # 자동 수정 + failed 워커 재시도
```

`--auto-fix` 동작:
1. tmux window 없는 워커 → `stale` 표시
2. `failed` 워커이고 `retry_count < max_retries` → 자동 재시도
3. corrupt JSON → 건너뜀 (unfixable 카운터 증가), exit 1 반환

### dashboard

```bash
scripts/orchestrator/dashboard          # 실시간 갱신 (watch -n 5)
scripts/orchestrator/dashboard --once   # 단일 스냅샷
scripts/orchestrator/dashboard --json   # JSON 출력
```

### enqueue-worker

```bash
scripts/orchestrator/enqueue-worker codex routes task-1
scripts/orchestrator/enqueue-worker codex auth auth-task \
  --priority 1 --spec docs/tasks/2026-03-31-auth.md
```

우선순위: 낮을수록 먼저 실행 (기본값 5, 최고 우선순위 1)

---

## 10. 환경 감지 (probe.sh)

`/start-harness` 실행 시 가장 먼저 `probe.sh`가 현재 환경을 감지한다.

```bash
"$HOME/.claude/skills/start-harness/scripts/probe.sh"
```

| 변수 | 의미 | 영향 |
|---|---|---|
| `HAS_TMUX_ORCHESTRATION=1` | tmux 세션 + scripts 존재 | 워커 위임 Path 1 활성화 |
| `TMUX_SESSION_READY=1` | 실제 세션 접근 가능 | window 생성 가능 여부 |
| `HAS_CODEX_PLUGIN=1` | codex-plugin-cc 설치됨 | 위임 Path 2 활성화 |
| `HAS_GSTACK=1` | gstack 전역 설치됨 | /review, /qa 등 사용 가능 |
| `HAS_SUPERPOWERS_WRITING_PLANS=1` | 작업 계획 자동화 가능 | 복잡한 multi-step 작업 |
| `HAS_SUPERPOWERS_SUBAGENT=1` | 서브에이전트 사용 가능 | 병렬 분할 실행 |
| `GH_READY=1` | gh CLI 인증됨 | GitHub 파이프라인 사용 가능 |

이 변수들이 오케스트레이션 매트릭스(Path 1~6) 중 어떤 경로를 탈지 결정한다.

---

## 11. 운영 체크리스트

### 새 작업을 시작할 때

```
[ ] docs/current.md 읽기 — 활성 스펙과 상태 확인
[ ] 상태가 done이면 이전 브랜치/이슈/PR 정리 완료 확인
[ ] GitHub 이슈 생성 (코드/문서 변경이 있는 경우)
[ ] codex/<issue-number>-slug 브랜치 생성
[ ] 작업 스펙 작성 (코드 변경 시) 또는 바로 작업 (docs-only 시)
```

### 구현이 끝났을 때

```
[ ] 검증 명령 통과 확인 (코드 변경 시)
    npm run build
    npx eslint "{src,apps,libs,test}/**/*.ts"
    CI=1 npm test -- --runInBand
    CI=1 npm run test:e2e -- --runInBand
[ ] docs-only라면 문서 링크/경로/정합성 확인
[ ] docs/current.md 상태 done으로 갱신
[ ] PR 생성 (한국어, Closes #번호 포함)
[ ] merge 후 이슈 닫힘 확인
[ ] 로컬/원격 브랜치 삭제
[ ] git switch main && git pull
```

### tmux 워커 운영 중 문제가 생겼을 때

```
[ ] scripts/orchestrator/recover-session
    → 상태 불일치 리포트 확인
[ ] scripts/orchestrator/capture-worker <worker-id>
    → 최근 출력 확인
[ ] scripts/orchestrator/mark-worker <worker-id> blocked "이유"
    → 수동 상태 갱신
[ ] scripts/orchestrator/recover-session --auto-fix
    → 자동 수정 + 재시도
```

---

## 참고 문서

| 문서 | 경로 |
|---|---|
| 에이전트 작업 정책 | `AGENTS.md` |
| 하네스 운영 절차 (상세) | `docs/operations/agent-handoff-harness.md` |
| GitHub 파이프라인 규칙 | `docs/operations/github-task-pipeline.md` |
| tmux 오케스트레이션 가이드 | `docs/operations/tmux-orchestration.md` |
| gstack 전역 설치 | `docs/operations/gstack-global-setup.md` |
| 현재 작업 상태 | `docs/current.md` |

---

*최초 작성: 2026-03-31 | 기준 저장소 상태: PR #16 merge 이후*
