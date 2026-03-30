# 헬스체크 라우트 및 e2e 테스트 후속 정리

날짜: 2026-03-30
작업자: Codex

## 작업 범위

Claude 세션이 남긴 컨텍스트를 이어받아 healthcheck 라우트 배선 누락과 e2e 테스트 불일치를 정리했다.

## 변경 내용

- `AppModule`에 `AppController`, `AppService`를 다시 등록해 `GET /` healthcheck가 실제 앱에서도 노출되도록 수정
- `test/app.e2e-spec.ts`에서 PrismaService를 mock하도록 바꿔 Prisma 7 generated client의 Jest 파싱 충돌을 우회
- e2e 응답 기대값을 기존 `"Hello World!"`에서 현재 계약 `{ status: 'ok' }`로 갱신
- `docs/current.md`에 이번 후속 정리 결과를 반영

## 결정 사항

- healthcheck e2e는 DB 연결이나 Prisma 실제 부팅에 의존하지 않도록 최소 mock 기반으로 유지한다.
- Prisma 7 generated client의 ESM 특성 때문에 기본 Nest scaffold e2e 구성을 그대로 두지 않는다.

## 다음 스텝

- Supabase 프로젝트 생성 후 `DATABASE_URL` 설정
- `npx prisma migrate dev --name init` 실행
- TMAP API 키 발급 후 실제 좌표 연동 완성
