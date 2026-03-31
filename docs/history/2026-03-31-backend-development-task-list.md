# 백엔드 개발 작업 목록 정리

날짜: 2026-03-31
작업자: Codex

## 작업 범위
현재 백엔드 개발에 필요한 후속 작업을 우선순위와 블로커 기준으로 정리했다.

## 변경 내용
- 외부 리소스 준비, DB 초기화, TMAP 실제 좌표 연동, Railway 배포, 운영 자동화 순으로 개발 로드맵을 정리했다.
- `docs/superpowers/plans/2026-03-31-backend-development-roadmap.md`에 다음 구현 순서를 문서화했다.
- `docs/current.md`에 즉시 실행할 다음 단계와 완료된 계획 정리 작업을 반영했다.

## 결정 사항
- 다음 구현 착수 전 선행 블로커는 `DATABASE_URL`과 `TMAP_API_KEY` 확보로 고정한다.
- 구현 순서는 `환경 준비 → Prisma migrate → TMAP 실제 좌표 연동 → Railway 배포 → heartbeat 자동화`로 진행한다.
- 활성 구현 스펙은 아직 만들지 않고, 외부 리소스 준비가 끝난 뒤 `/start-harness 활성 스펙 기준 구현`으로 이어간다.

## 다음 스텝
- Supabase 프로젝트 생성 후 `DATABASE_URL`을 `.env`에 반영
- TMAP API 키 발급
- `npx prisma migrate dev --name init` 실행
- 활성 구현 스펙 생성 후 실제 코드 작업 시작
