# sora-backend

**Sora** — "지금 출발하면 지각할까?"를 즉시 계산하고, 실제 지각 여부를 기록해 습관을 개선하는 모바일 PWA의 백엔드 서버입니다.

> 연관 저장소: [earlydreamer/sora-frontend](https://github.com/earlydreamer/sora-frontend)

---

## 기술 스택

| 항목 | 선택 |
|---|---|
| 런타임 | Node.js + NestJS |
| ORM | Prisma 7 |
| 데이터베이스 | Supabase (PostgreSQL) |
| 인증 | JWT + bcrypt (NestJS 직접 구현) |
| 대중교통 API | TMAP (SK Telecom) — 서버사이드 프록시 |
| 배포 | Railway |

## 로컬 개발 환경

```bash
# 의존성 설치
npm install

# 환경변수 설정
cp .env.example .env
# .env의 DATABASE_URL, JWT_SECRET, TMAP_API_KEY 값 채우기

# Prisma 클라이언트 생성
npx prisma generate

# DB 마이그레이션 (Supabase 연결 후)
npx prisma migrate dev

# 개발 서버 시작
npm run start:dev
```

## API 구조

| 모듈 | 엔드포인트 | 설명 |
|---|---|---|
| Auth | `POST /auth/register` | 이메일 회원가입 |
| Auth | `POST /auth/login` | 로그인, JWT 반환 |
| Routes | `GET /routes` | 경로 목록 조회 |
| Routes | `POST /routes` | 경로 등록 (최대 2개) |
| Routes | `PATCH /routes/:id` | 경로 수정 |
| Routes | `DELETE /routes/:id` | 경로 삭제 |
| Transit | `GET /transit/eta` | TMAP ETA 조회 + 지각 계산 |
| Departures | `GET /departures` | 출발 기록 목록 |
| Departures | `GET /departures?status=pending` | 미기록 세션 조회 |
| Departures | `POST /departures` | 출발 기록 저장 |
| Departures | `PATCH /departures/:id` | 실제 지각 여부 기록 |

## 에이전트 작업 가이드

Claude와 Codex의 역할 분리, gstack 운영 원칙은 [AGENTS.md](./AGENTS.md)를 참고합니다.

gstack 전역 설치·업그레이드 절차는 [docs/operations/gstack-global-setup.md](./docs/operations/gstack-global-setup.md)를 참고합니다.

---

## 개발 정책

- 커밋 메시지와 문서는 **한국어 우선**
- API 키는 절대 프론트엔드에 노출하지 않음 (TMAP 서버사이드 프록시)
- Prisma schema 변경 시 반드시 migration 생성 후 커밋
