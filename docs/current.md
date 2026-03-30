# 현재 작업 컨텍스트

최종 업데이트: 2026-03-31 00:28
업데이트 주체: Codex

## 프로젝트 상태

백엔드 scaffold 완료 + /review 지적 사항 전체 반영 + healthcheck/e2e 검증 정비 완료. DB 연결(Supabase) 및 TMAP API 키 발급 대기 중.

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
- **운영 하네스**: Claude와 Codex를 상태 + 산출물 기반으로 연결하는 handoff harness spec 초안을 `docs/superpowers/specs/2026-03-30-agent-handoff-harness-design.md`에 정리했고, 사람용 개요와 도식은 `docs/operations/agent-handoff-harness-overview.md`로 분리했다.

## 작업 체크리스트

### 진행 중
- [ ] Supabase 프로젝트 생성 후 DATABASE_URL 발급 (담당: 사람)
- [ ] TMAP API 키 발급 (담당: 사람)

### 대기 중 (블로커 있음)
- [ ] `npx prisma migrate dev --name init` 실행 — 블로커: DATABASE_URL 미설정
- [ ] `transit.service.ts` TMAP 실제 좌표 연동 완성 — 블로커: TMAP API 키 미발급
- [ ] Railway 배포 설정 — 블로커: DB 연결 선행 필요
- [ ] GitHub Actions heartbeat 설정 (Supabase 7일 비활성 방지) — 블로커: Supabase 프로젝트 생성 선행

### 완료
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
- [x] /review 지적 사항 전체 반영:
  - P2002 동시 register 409 처리 (auth.service.ts)
  - safeDepatureAt → safeDepartureAt 오타 수정 (transit.service.ts, transit.controller.ts)
  - KST 변환 TODO 주석 추가 (transit.service.ts formatTmapDatetime)
  - CORS 프로덕션 제한 TODO 주석 (main.ts)
  - etaMinutes 음수 방어 Math.max(0, ...) (departures.service.ts)
  - GET / healthcheck 반환값 { status: 'ok' } (app.controller.ts, app.service.ts)
  - RequestWithUser 공통 타입 (src/types/request-with-user.ts)
  - ESLint `_`-prefix argsIgnorePattern 추가 (eslint.config.mjs)
