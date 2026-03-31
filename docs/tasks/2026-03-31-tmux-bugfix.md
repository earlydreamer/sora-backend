# tmux 오케스트레이터 버그 수정 (Issue #11)

**상태**: in-progress
**연결 이슈**: #11
**브랜치**: codex/11-tmux-orchestrator-bugfix

## 범위

`scripts/orchestrator/` 의 16개 버그 수정 (engineering review + codex challenge 결과).

## 수정 대상 파일

- `scripts/orchestrator/lib.sh`
- `scripts/orchestrator/spawn-worker`
- `scripts/orchestrator/recover-session`
- `scripts/orchestrator/capture-worker`
- `scripts/orchestrator/dashboard`
- `scripts/orchestrator/mark-worker`
- `scripts/test-tmux-unit.sh` (신규)

## 수정 내용 요약

### lib.sh
- SESSION_NAME: `sora-backend` 하드코딩 → `$(basename "$REPO_ROOT")` 동적 생성 [M1]
- next_worker_id(): find|wc -l → max suffix + 1 방식 [C2]
- queue_push(): 입력값 jq --arg 이스케이프 [L1/H4]
- queue_pop(): pop 후 tmux 실패 시 복구 로직은 spawn-worker에서 처리

### spawn-worker
- window_name: `worker-${worker_id}-...` → `${worker_id}-${agent}-${slug}` (double-prefix 제거) [C1]
- state.json workers[] 업데이트 실제 구현 [C5]
- --split-log: split 후 pane 0 명시적 타겟, worker 명령에 `tee log_file` 추가 [H1]
- worker JSON heredoc → jq --arg 이스케이프 [L1]
- --from-queue: tmux 실패 시 queue_push로 복구 [C4]

### recover-session
- tmux 세션 존재 여부 먼저 확인 [C6]
- retry: 새 worker spawn 대신 기존 JSON을 'retrying'으로 갱신 후 spawn-worker 호출로 교체 [C3]

### capture-worker
- log_success/log_info → stderr 이동 [H2]
- capture 대상: window → pane 0 명시 [H3]

### dashboard
- watch exec quoting: `sh -c '... --once'` 패턴 [M3]
- --json 출력: raw 필드 → jq --arg 이스케이프 [L1]
- validate_worker_json() 호출 추가 [M2]

### mark-worker
- 허용 상태(done/blocked/failed/running/retrying) 외 입력 거부 [L2]

### scripts/test-tmux-unit.sh (신규)
- next_worker_id() 단위 테스트 (tmux 없이)
- queue_push/pop/list 단위 테스트
- iso8601_now() 형식 검증

## 완료 조건

- [ ] `bash -n scripts/orchestrator/*.sh scripts/orchestrator/lib.sh` 통과
- [ ] `bash -n scripts/orchestrator/spawn-worker` 등 각 스크립트 통과
- [ ] `bash scripts/test-tmux-unit.sh` 통과
- [ ] `npm run build` 통과
- [ ] `npm run lint` 통과
- [ ] `npm test -- --runInBand` 통과
