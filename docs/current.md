# 현재 작업 컨텍스트

최종 업데이트: 2026-03-30
업데이트 주체: Claude

## 프로젝트 상태

백엔드 scaffold 완료. DB 연결(Supabase) 및 TMAP API 키 발급 대기 중.

## 활성 컨텍스트

- **스택**: NestJS + Prisma 7 + Supabase PostgreSQL + Railway 배포
- **인증**: NestJS JWT + bcrypt 직접 구현 (Supabase Auth 미사용)
- **TMAP**: 서버사이드 프록시 전용. 키는 `.env`의 `TMAP_API_KEY`. 아직 미발급.
- **Prisma**: schema 작성 완료, `generate` 완료. `migrate`는 DB 연결 후 실행.
- **주소 입력**: Phase 1은 수동 텍스트. TMAP Geocoding autocomplete는 Phase 2.
- **transit.service.ts**: TMAP API 연동 골격 작성됨. 실제 좌표(startX/Y, endX/Y) 연동 미완료.

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
