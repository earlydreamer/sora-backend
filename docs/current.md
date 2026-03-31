# 현재 작업 컨텍스트

최종 업데이트: 2026-04-01 00:16
업데이트 주체: Codex

## 프로젝트 상태

`start-harness` 트리거 구조와 tmux 오케스트레이션 계약 정비를 완료했고, 실제 tmux Codex worker가 격리 runtime home으로 안정적으로 동작함을 재검증했다. 기존 백엔드 scaffold는 유지되며, 하네스 문서/skill/스크립트/테스트가 같은 해석으로 동작한다.

## 활성 컨텍스트

- **스택**: NestJS + Prisma 7 + Supabase PostgreSQL + Railway 배포
- **인증**: NestJS JWT + bcrypt 직접 구현 (Supabase Auth 미사용)
- **TMAP**: 서버사이드 프록시 전용. 키는 `.env`의 `TMAP_API_KEY`. 아직 미발급.
- **Prisma**: schema 작성 완료, `generate` 완료. `migrate`는 DB 연결 후 실행.
- **주소 입력**: Phase 1은 수동 텍스트. TMAP Geocoding autocomplete는 Phase 2.
- **transit.service.ts**: TMAP API 연동 골격 작성됨. 실제 좌표(startX/Y, endX/Y) 연동 미완료(Phase 2).
- **RequestWithUser**: `src/types/request-with-user.ts` — 컨트롤러 req 타입 공통 인터페이스.
- **healthcheck**: `AppModule`에 `AppController`, `AppService`가 다시 연결되어 `GET /`가 앱 레벨에서도 노출된다.
- **e2e 테스트**: Prisma 7 generated client의 `import.meta` 문제를 피하도록 PrismaService를 mock하고 현재 응답 계약 `{ status: 'ok' }` 기준으로 검증한다.
- **운영 하네스**: `docs/operations/agent-handoff-harness.md`, `docs/operations/agent-handoff-harness-overview.md`, `docs/tasks/`, `AGENTS.md`에 backend 저장소용 handoff harness 규칙을 반영했다.
- **start-harness 오케스트레이션**: `/start-harness`는 전달된 명령과 프롬프트를 기준으로 superpowers, gstack, repo-local workflow, 기타 지원 skill/명령 중 가장 적절한 흐름을 먼저 고른 뒤 하네스를 이어간다.
- **리뷰 루프 제한**: 같은 파일/같은 task에서 reviewer 수정 루프는 최대 2회까지만 반복하고, 이후에는 blocking 이슈만 추가 수정한 뒤 다음 단계로 진행한다.
- **리뷰 기준**: Windows/Linux/Unix 환경 차이에서만 생기는 인코딩, 개행 문자, 실행 비트 차이는 무시하고 실제 코드 동작 변경만 검토한다.
- **GitHub 파이프라인**: 신규 작업은 `gh` 기반 한국어 issue 생성 → `codex/<issue-number>-brief-slug` 브랜치 작업 → 한국어 PR → `main` merge → issue/PR/브랜치 정리 순서로 진행한다.
- **개발 로드맵**: [issue #1](https://github.com/earlydreamer/sora-backend/issues/1) 기준으로 `docs/superpowers/plans/2026-03-31-backend-development-roadmap.md`에 다음 개발 순서를 정리했다.
- **codex-plugin-cc**: `HAS_CODEX_PLUGIN` probe 변수 추가. 플러그인 설치 후 tmux 없이도 실제 Codex CLI 위임 가능 (tier 2). 설치: `/plugin marketplace add openai/codex-plugin-cc` → `/plugin install codex@openai-codex` → `/reload-plugins` → `/codex:setup`
- **tmux 오케스트레이션**: 1~5단계 완료. helper script (`spawn-worker`, `list-workers`, `capture-worker`, `mark-worker`, `recover-session`, `dashboard`, `enqueue-worker`)를 `scripts/orchestrator/`에 구현. 4단계에서 TUI 상태판(`dashboard`), 우선순위 큐(`enqueue-worker`), pane 기반 로그(`--split-log`), 자동 재시도(`--retry N`) 추가.
- **tmux Codex runtime isolation**: `spawn-worker`는 Codex worker마다 `.orchestrator/runtime/codex-home/<worker-id>`를 준비해 `CODEX_HOME`을 격리한다. 실제 tmux live smoke에서 `TMUX_ISOLATED_OK`, `HAS_LOGS_IO_ERROR=0`, `HAS_STATE_WARNING=0`을 확인했다.
- **최근 완료 task**: GitHub issue #19 / branch `codex/19-start-harness-orchestration-hardening`
- **이번 정비 결과**: `start-harness`를 thin trigger + downstream ownership 구조로 재정의하고, 설치본 skill pack과 backend tmux helper script/test 계약을 일치시켰다.
- **GitHub 게이트 원칙**: `1 작업 = 1 이슈 = 1 브랜치 = 1 PR` 구조는 유지하되, `gh` hard gate는 실제 tracked task 생성/PR/merge 단계에서만 강제한다.
- **분산 책임 명시**: Verify/Correct는 `start-harness`가 직접 수행하는 것이 아니라 gstack, superpowers, repo verification, tmux helper script가 나눠 맡는다.
- **남은 운영 경고**: 일부 MCP/plugin OAuth `invalid_token` 경고는 남아 있지만, tmux worker 실행 성공/실패를 가르는 blocker는 아니다.

## 하네스 상태
- 상태: done
- 현재 담당: 사람
- 활성 스펙: 없음
- Claude 재판단 필요: 없음

## 작업 체크리스트

### 진행 중
- [ ] Supabase 프로젝트 생성 후 DATABASE_URL 발급 (담당: 사람)
- [ ] TMAP API 키 발급 (담당: 사람)
- [ ] 외부 리소스 준비 완료 후 활성 구현 스펙 생성 (담당: Codex)

### 대기 중 (블로커 있음)
- [ ] `npx prisma migrate dev --name init` 실행 — 블로커: DATABASE_URL 미설정
- [ ] `transit.service.ts` TMAP 실제 좌표 연동 완성 — 블로커: TMAP API 키 미발급
- [ ] Railway 배포 설정 — 블로커: DB 연결 선행 필요
- [ ] GitHub Actions heartbeat 설정 (Supabase 7일 비활성 방지) — 블로커: Supabase 프로젝트 생성 선행

### 완료
- [x] 백엔드 개발 작업 목록과 우선순위 문서화
- [x] gstack 전역 설치 및 운영 문서화
- [x] NestJS scaffold (Prisma 7, TypeScript, ESLint)
- [x] 의존성 설치 (JWT, bcrypt, Prisma, class-validator 등)
- [x] Prisma 스키마 작성 (User, Route, DepartureRecord)
- [x] PrismaModule (글로벌)
- [x] AuthModule (register, login, JWT, bcrypt)
- [x] RoutesModule (CRUD, 최대 2개, 기본 경로 자동 지정)
- [x] TransitModule (TMAP ETA 프록시, 지각 계산, 버퍼 반영)
- [x] DeparturesModule (출발 기록 저장, pending 조회, 지각 여부 기록)
- [x] main.ts: ValidationPipe, CORS 전역 설정
- [x] README, AGENTS.md, docs/ 문서 체계 수립
- [x] `GET /` healthcheck 라우트 AppModule 연결 복구
- [x] `test/app.e2e-spec.ts`를 현재 healthcheck 계약 기준으로 정비
- [x] Claude-Codex handoff harness 공통 spec 초안 작성
- [x] handoff harness backend rollout implementation plan 작성
- [x] handoff harness 운영 절차 문서 추가
- [x] AGENTS에 handoff harness 게이트와 리뷰 루프 제한 반영
- [x] `docs/tasks/` handoff 템플릿 및 사용 규칙 추가
- [x] GitHub issue/PR 기반 작업 파이프라인 문서화
- [x] `/start-harness`가 superpowers/gstack/지원 skill 전체를 대상으로 가장 적절한 흐름을 먼저 선택하도록 오케스트레이션 규칙 강화
- [x] tmux 오케스트레이션 1단계 문서 계약 반영 (spec, 운영 가이드)
- [x] 리뷰 시 OS별 인코딩/개행/실행 비트 차이는 무시하고 실제 코드 변경만 보도록 지침 추가
- [x] tmux 오케스트레이션 2단계 helper script 구현:
  - spawn-worker (--auto-start 옵션 포함)
  - list-workers (--json 옵션 포함)
  - capture-worker
  - mark-worker
  - recover-session
  - lib.sh 공통 함수 라이브러리
- [x] /review 지적 사항 전체 반영:
  - P2002 동시 register 409 처리 (auth.service.ts)
  - safeDepatureAt → safeDepartureAt 오타 수정 (transit.service.ts, transit.controller.ts)
  - KST 변환 TODO 주석 추가 (transit.service.ts formatTmapDatetime)
  - CORS 프로덕션 제한 TODO 주석 (main.ts)
  - etaMinutes 음수 방어 Math.max(0, ...) (departures.service.ts)
  - GET / healthcheck 반환값 { status: 'ok' } (app.controller.ts, app.service.ts)
  - RequestWithUser 공통 타입 (src/types/request-with-user.ts)
  - ESLint `_`-prefix argsIgnorePattern 추가 (eslint.config.mjs)
- [x] tmux 오케스트레이션 3단계 start-harness skill 통합:
  - probe.sh 확장 (HAS_TMUX_ORCHESTRATION, TMUX_SESSION_READY 감지)
  - SKILL.md 확장 (6번째 오케스트레이션 경로: worker-dispatch-ready 상태 처리)
  - 병렬 워커 위임 흐름 구현 (30초 폴링, 모니터링 루프, 게이팅)
  - 테스트 하네스 생성 (test-tmux-integration.sh)
  - GitHub issue #7, PR #8 통합 및 merge 완료
- [x] tmux 오케스트레이션 4단계 선택적 고도화:
  - dashboard (TUI 상태판: ANSI color, --once, --json)
  - enqueue-worker (우선순위 큐: .orchestrator/queue.json)
  - spawn-worker: --split-log, --retry N, --from-queue 옵션 추가
  - recover-session: --auto-fix에서 failed 워커 자동 재시도
  - lib.sh: queue_push, queue_pop, queue_list 공통 함수 추가
  - GitHub issue #9, PR #10 통합 및 merge 완료
- [x] tmux 오케스트레이션 5단계 버그 수정:
  - engineering review + codex challenge 발견 16개 버그 전체 수정
  - SESSION_NAME 동적화 (REPO_ROOT basename 기반)
  - window name double-prefix 제거 (worker-001-agent-slug)
  - next_worker_id(): max suffix+1 방식 (경쟁 조건, ID 재사용 방지)
  - recover-session retry: 기존 JSON retrying 갱신 (좀비 방지)
  - --from-queue: tmux 실패 시 queue 복구
  - state.json workers[] 실제 업데이트 구현
  - 로그 함수 전체 stderr 이동 (stdout 오염 제거)
  - capture-worker pane 0 명시 (--split-log 시 비결정 방지)
  - validate_worker_json() 호출 추가
  - mark-worker 상태 유효성 검사
  - jq --arg 이스케이프 (invalid JSON 방지)
  - scripts/test-tmux-unit.sh: 16개 단위 테스트
  - GitHub issue #11, PR #12 통합 및 merge 완료
- [x] `start-harness` thin trigger + downstream ownership 구조 정비
- [x] 설치본 `start-harness-pack`, probe.sh, backend tmux helper/test 계약 동기화
- [x] live tmux smoke + 통합/단위 테스트 재검증
- [x] `.orchestrator/` 런타임 산출물 git ignore 반영
- [x] tmux Codex worker runtime isolation 반영 및 실제 live smoke 재검증
