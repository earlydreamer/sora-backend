# tmux Codex runtime isolation

날짜: 2026-04-01
작업자: Codex

## 작업 범위
tmux worker에서 실제 `codex exec`를 다시 검증하고, 데스크톱 Codex와의 SQLite 충돌을 피하도록 worker 런타임을 분리했다.

## 변경 내용
- `scripts/orchestrator/lib.sh`에 worker별 Codex runtime home 준비 함수를 추가했다.
- `scripts/orchestrator/spawn-worker`가 Codex worker command 앞에 repo-local `CODEX_HOME`을 주입하도록 바꿨다.
- `scripts/test-tmux-unit.sh`, `scripts/test-tmux-integration.sh`에 격리 runtime home 계약 테스트를 추가했다.
- 실제 tmux window에서 `codex exec`를 재실행해 `TMUX_ISOLATED_OK`, `HAS_LOGS_IO_ERROR=0`, `HAS_STATE_WARNING=0`을 확인했다.

## 결정 사항
- tmux worker는 전역 `~/.codex`를 그대로 공유하지 않는다.
- 공유가 필요한 것은 `auth.json`, `config.toml`, `skills`, `plugins` 같은 설정 자산이고, SQLite 상태/log/session 계층은 worker별로 분리한다.
- 남은 경고 중 일부 MCP/plugin OAuth `invalid_token`은 tmux 실행 자체를 막지 않는 비기능 경고로 본다.

## 다음 스텝
- 필요하면 만료된 MCP/plugin OAuth 토큰을 정리해 stderr 노이즈를 줄인다.
- frontend 저장소에 동일한 worker runtime isolation 계약을 문서로 반영한다.
