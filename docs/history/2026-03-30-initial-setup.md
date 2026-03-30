# 백엔드 초기 설정 및 scaffold

날짜: 2026-03-30
작업자: Claude

## 작업 범위

기획(office-hours) → 아키텍처 검토(eng-review) → NestJS scaffold + 모듈 구현까지 완료.

## 변경 내용

- gstack 도입 및 전역 설치 문서화
- NestJS 백엔드 초기 scaffold (Prisma 7, JWT 인증, TMAP 프록시 구조)
- 모듈 구현: Auth, Routes, Transit, Departures, PrismaModule
- Prisma 스키마: User, Route, DepartureRecord
- README 재작성 (프로젝트 개요, API 구조, 연관 저장소 링크)
- AGENTS.md 정책 수립 (커밋 규칙, 문서 구조, 히스토리, 자동화 계약)

## 결정 사항

- 런타임: NestJS (Spring Boot 대비 RAM 100-150MB, Railway 무료 크레딧 적합)
- DB: Supabase 무료 PostgreSQL + GitHub Actions 일 1회 heartbeat
- 배포: Railway (백엔드), Cloudflare Pages (프론트엔드)
- 인증: NestJS 직접 구현 JWT + bcrypt (Supabase Auth 미사용, 포트폴리오 가치)
- TMAP API: 서버사이드 프록시만 허용, 키 프론트 노출 금지
- ODsay: 정책 이슈로 미사용, TMAP으로 시작
- 주소 입력: 수동 텍스트 (Phase 1 본인 사용, autocomplete 불필요)
- 지각 기록 트리거: 앱 오픈 시 미기록 배너 (푸시 알림 MVP 제외)

## 다음 스텝

- Supabase 프로젝트 생성 후 DATABASE_URL 환경변수 설정
- `npx prisma migrate dev --name init` 실행
- TMAP API 키 발급 후 transit.service.ts 실제 연동 완성
- Railway 배포 설정
- GitHub Actions heartbeat 설정 (Supabase 7일 비활성 방지)
