# tmux 오케스트레이션 1단계 문서 계약

날짜: 2026-03-31
작업자: Codex

## 작업 범위

tmux 기반 멀티에이전트 오케스트레이션의 1단계 문서 계약을 저장소 운영 문서로 고정했다.

## 변경 내용

- `docs/superpowers/specs/2026-03-31-tmux-orchestration-design.md`를 추가해 WSL2, Tailscale, systemd, `.orchestrator/` git 정책, 복구 규약을 포함한 설계 spec을 정리했다.
- `docs/operations/tmux-orchestration.md`를 추가해 WSL2 systemd, SSH, Tailscale, tmux 운영 절차를 문서화했다.
- `docs/current.md`에 tmux 오케스트레이션 문서 계약 반영 사실을 현재 컨텍스트로 추가했다.
- 저장소 필수 검증을 다시 실행해 현재 `main` 기준의 실패 원인도 함께 확인했다.

## 결정 사항

- 초기 오케스트레이션 단위는 `tmux pane`이 아니라 `window`로 고정한다.
- 상태 저장은 사람용 Markdown과 기계용 JSON을 분리하는 `MD + JSON` 이중 레이어를 사용한다.
- 1단계에서는 문서 계약만 추가하고 helper script 구현은 2단계로 넘긴다.

## 다음 스텝

- helper script 최소 구현 범위를 확정한다.
- `.orchestrator/` 런타임 파일의 실제 `.gitignore` 반영 시점을 정한다.
- SSH 환경에서 시범 세션을 열어 문서 절차가 실제로 재현되는지 확인한다.
- Prisma generated client와 `JWT_SECRET` 기준선 문제를 정리한 뒤 merge 가능 상태로 만든다.
