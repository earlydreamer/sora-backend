# Sora Backend Development Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 외부 의존성 준비부터 실제 대중교통 연동과 배포까지, 백엔드가 실사용 가능한 상태로 이어지는 후속 개발 작업을 우선순위대로 정리한다.

**Architecture:** 현재 NestJS 모듈 구조와 Prisma 스키마를 유지한 채, 외부 리소스 준비를 선행하고 그 위에 DB 초기화, TMAP 실제 좌표 연동, 배포/운영 자동화를 순차적으로 쌓는다. 각 단계는 이전 단계의 블로커를 해소하는 방식으로 구성해 구현 순서가 문서만 봐도 드러나도록 한다.

**Tech Stack:** NestJS, Prisma 7, Supabase PostgreSQL, TMAP API, Railway, GitHub Actions

---

### Task 1: 외부 리소스와 로컬 환경 준비

**Files:**
- Modify: `README.md`
- Modify: `docs/current.md`
- Reference: `.env.example`

- [ ] **Step 1: Supabase 프로젝트를 생성하고 연결 문자열을 확보한다**

Run:

```bash
cp .env.example .env
```

Expected:

```text
.env 파일이 생성되고 DATABASE_URL 입력 위치를 확인할 수 있다.
```

- [ ] **Step 2: `.env`에 `DATABASE_URL`, `JWT_SECRET`, `TMAP_API_KEY`를 채운다**

Check:

```bash
rg -n "DATABASE_URL|JWT_SECRET|TMAP_API_KEY" .env .env.example
```

Expected:

```text
.env.example의 키와 동일한 항목이 .env에 존재한다.
```

- [ ] **Step 3: 작업 상태판을 현재 리소스 준비 상태로 갱신한다**

Modify:

```md
- [ ] Supabase 프로젝트 생성 후 DATABASE_URL 발급
- [ ] TMAP API 키 발급
```

Expected:

```text
docs/current.md의 진행/대기 상태가 실제 준비 상태와 일치한다.
```

### Task 2: Prisma 초기화와 기본 검증

**Files:**
- Modify: `prisma/schema.prisma`
- Modify: `README.md`
- Modify: `docs/current.md`
- Create: `prisma/migrations/<timestamp>_init/*`

- [ ] **Step 1: Prisma client를 다시 생성한다**

Run:

```bash
npx prisma generate
```

Expected:

```text
Prisma Client generated
```

- [ ] **Step 2: 첫 migration을 생성한다**

Run:

```bash
npx prisma migrate dev --name init
```

Expected:

```text
Applying migration `..._init`
```

- [ ] **Step 3: 저장소 기본 검증을 수행한다**

Run:

```bash
npm run build
npm run lint
CI=1 npm test -- --runInBand
CI=1 npm run test:e2e -- --runInBand
```

Expected:

```text
모든 명령이 성공하고 현재 스캐폴드 기준 테스트가 유지된다.
```

### Task 3: TMAP 실제 좌표 연동 완성

**Files:**
- Modify: `src/transit/transit.service.ts`
- Modify: `src/transit/transit.controller.ts`
- Modify: `README.md`
- Test: `test/app.e2e-spec.ts`

- [ ] **Step 1: 주소 입력값을 TMAP 좌표로 변환하는 흐름을 설계한다**

Check:

```bash
sed -n '1,220p' src/transit/transit.service.ts
```

Expected:

```text
현재 TODO로 남아 있는 geocoding 좌표 변환 지점을 확인한다.
```

- [ ] **Step 2: origin/destination을 좌표로 바꾼 뒤 ETA 호출에 연결한다**

Implement target:

```ts
// origin, destination 주소를 geocoding 후 startX/startY/endX/endY에 연결
```

Expected:

```text
TMAP ETA 요청이 하드코딩 없는 실제 좌표 기반으로 동작한다.
```

- [ ] **Step 3: 예외 처리와 회귀 검증을 추가한다**

Run:

```bash
npm run build
npm run lint
CI=1 npm test -- --runInBand
CI=1 npm run test:e2e -- --runInBand
```

Expected:

```text
TMAP 키 누락, 응답 실패, 타임아웃 방어가 기존 계약을 깨지 않는다.
```

### Task 4: Railway 배포 연결

**Files:**
- Modify: `README.md`
- Modify: `docs/current.md`
- Modify: 필요 시 `package.json`

- [ ] **Step 1: Railway 프로젝트를 생성하고 환경변수를 동기화한다**

Required vars:

```text
DATABASE_URL
JWT_SECRET
TMAP_API_KEY
PORT
```

Expected:

```text
로컬과 Railway에서 동일한 런타임 설정을 사용할 수 있다.
```

- [ ] **Step 2: 배포 후 healthcheck를 검증한다**

Run:

```bash
curl <railway-url>/
```

Expected:

```json
{"status":"ok"}
```

- [ ] **Step 3: 주요 API smoke test를 수행한다**

Check endpoints:

```text
POST /auth/register
POST /auth/login
GET /routes
GET /transit/eta
```

Expected:

```text
인증, 기본 데이터 접근, ETA 계산 경로가 배포 환경에서도 응답한다.
```

### Task 5: 운영 자동화와 후속 안정화

**Files:**
- Modify: `.github/workflows/<heartbeat>.yml`
- Modify: `docs/current.md`
- Modify: `README.md`
- Create: `docs/history/2026-03-31-backend-development-task-list.md`

- [ ] **Step 1: Supabase 비활성 방지 heartbeat를 추가한다**

Implement target:

```yaml
on:
  schedule:
    - cron: '0 0 * * *'
```

Expected:

```text
7일 비활성으로 인한 DB sleep 위험을 줄인다.
```

- [ ] **Step 2: 운영 문서와 현재 상태판을 최신화한다**

Update targets:

```text
docs/current.md
README.md
docs/history/*
```

Expected:

```text
새 에이전트가 현재 배포/운영 상태를 문서만 보고 이어받을 수 있다.
```

- [ ] **Step 3: 다음 우선순위 구현 후보를 재평가한다**

Review list:

```text
주소 autocomplete
출발 기록 UX 지원 API
운영 모니터링
```

Expected:

```text
Phase 2 이후 backlog가 활성 스펙 후보 수준으로 정리된다.
```
