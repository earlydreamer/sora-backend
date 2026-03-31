# tmux 오케스트레이션 2단계 구현 계획

> **에이전트 작업자용:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` 또는 `superpowers:executing-plans`를 사용해 이 계획을 실행한다. 진행 추적은 체크박스(`- [ ]`) 문법을 사용한다.

**목표:** 5개 helper script (`spawn-worker`, `list-workers`, `capture-worker`, `mark-worker`, `recover-session`)를 Bash로 구현하고, `spawn-worker`에 `--auto-start` 옵션을 추가해 tmux send-keys 기반 자동 트리거를 실현한다.

**아키텍처:** helper script는 `.orchestrator/` 상태 파일을 읽고 쓰며, tmux 명령을 조합해 워커를 생성·관리한다. `--auto-start`는 새 window 생성 후 초기 Claude/Codex 명령을 자동으로 주입한다.

**기술 스택:** Bash, jq (JSON 파싱), tmux, WSL2

---

## 준비 단계

**GitHub Issue 생성** (AGENTS.md 규칙)

아래 내용으로 한국어 issue를 생성한다.

```md
## 배경

tmux 오케스트레이션 1단계(문서 계약)가 완료됐고, 이제 실제 워커 관리 스크립트를 구현해야 한다. 5개 helper script는 `.orchestrator/` 상태를 기반으로 tmux window를 생성하고 모니터링하며, spawn-worker의 --auto-start 옵션으로 자동 트리거를 지원한다.

## 목표

1. spawn-worker: 새 worker window 생성 + 초기 명령 주입
2. list-workers: 등록된 worker와 실제 tmux window 상태 비교
3. capture-worker: window 최근 출력 캡처 (복구/디버깅 용)
4. mark-worker: worker 상태 전이 (done/blocked/failed 기록)
5. recover-session: 세션 상태 복구 및 정규화

## 범위

- `scripts/orchestrator/` 디렉터리 생성
- 5개 script 파일 (.sh) 작성
- `.orchestrator/` 상태 파일 구조 예시 추가
- script 간 공통 함수 라이브러리 (`lib.sh`)
- 권한 설정 및 PATH 등록

## 완료 조건

- [ ] `npm run build` 통과 (코드 아님, 문서만)
- [ ] `npm run lint` 통과 (코드 아님, 문서만)
- [ ] 5개 script 모두 `bash -n` (문법 검증) 통과
- [ ] 각 script가 `--help` 출력 지원
- [ ] `.orchestrator/` 상태 파일 예시가 README에 포함됨
- [ ] 로컬 테스트: `spawn-worker codex test test-1 --auto-start` 실행 가능
```

---

## Task 1: `scripts/orchestrator/` 디렉터리 구조 설정

**Files:**
- Create: `scripts/orchestrator/`
- Create: `scripts/orchestrator/lib.sh`
- Modify: `.gitignore` (scripts는 추적)

- [ ] **Step 1: 디렉터리 생성**

```bash
mkdir -p scripts/orchestrator
```

- [ ] **Step 2: 공통 라이브러리 작성**

다음 내용으로 `scripts/orchestrator/lib.sh`를 작성한다.

```bash
#!/bin/bash
# Common functions for orchestrator scripts

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Directory constants
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ORCHESTRATOR_DIR="${REPO_ROOT}/.orchestrator"
STATE_FILE="${ORCHESTRATOR_DIR}/state.json"
WORKERS_DIR="${ORCHESTRATOR_DIR}/workers"
LOGS_DIR="${ORCHESTRATOR_DIR}/logs"

# Ensure orchestrator directories exist
ensure_dirs() {
  mkdir -p "${ORCHESTRATOR_DIR}" "${WORKERS_DIR}" "${LOGS_DIR}"
}

# Initialize state.json if not exists
init_state() {
  if [ ! -f "${STATE_FILE}" ]; then
    cat > "${STATE_FILE}" <<EOF
{
  "session_id": "sora-backend",
  "repo_path": "${REPO_ROOT}",
  "control_window": "control",
  "active_spec": "",
  "controller": {
    "agent": "unknown",
    "status": "idle",
    "last_heartbeat": "$(date -u +'%Y-%m-%dT%H:%M:%S%z')"
  },
  "workers": []
}
EOF
    log_info "Initialized state.json"
  fi
}

# Generate next worker ID
next_worker_id() {
  local count
  count=$(find "${WORKERS_DIR}" -name "worker-*.json" 2>/dev/null | wc -l)
  printf "worker-%03d" $((count + 1))
}

# Format ISO 8601 timestamp
iso8601_now() {
  date -u +'%Y-%m-%dT%H:%M:%S%z'
}

# Validate worker JSON format
validate_worker_json() {
  local worker_file="$1"
  if ! jq empty "${worker_file}" 2>/dev/null; then
    log_error "Invalid JSON: ${worker_file}"
    return 1
  fi
}

# Get session status from tmux
tmux_session_exists() {
  tmux has-session -t sora-backend 2>/dev/null
}

export -f log_info log_success log_warn log_error
export -f ensure_dirs init_state next_worker_id iso8601_now validate_worker_json tmux_session_exists
export REPO_ROOT ORCHESTRATOR_DIR STATE_FILE WORKERS_DIR LOGS_DIR
```

- [ ] **Step 3: 권한 설정**

```bash
chmod +x scripts/orchestrator/lib.sh
```

---

## Task 2: `spawn-worker` 구현

**Files:**
- Create: `scripts/orchestrator/spawn-worker`
- Reference: `lib.sh`

- [ ] **Step 1: 스크립트 기본 구조 작성**

다음 내용으로 `scripts/orchestrator/spawn-worker`를 작성한다.

```bash
#!/bin/bash
# spawn-worker: Create new tmux window for a worker agent

set -euo pipefail

source "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
Usage: spawn-worker [OPTIONS] <agent> <slug> <task-ref>

Create a new tmux window and register a worker.

Arguments:
  agent           Agent type: codex, gemini, etc.
  slug            Brief slug for the task (e.g., routes, auth)
  task-ref        Task reference or spec path (e.g., task-1, docs/tasks/2026-03-31-routes.md)

Options:
  --spec FILE          Path to task specification file
  --auto-start         Automatically start the agent with task command
  --command CMD        Initial command to send to the window
  --help               Show this help message

Examples:
  spawn-worker codex routes task-1
  spawn-worker codex routes task-1 --spec docs/tasks/2026-03-31-routes.md --auto-start
  spawn-worker codex auth auth-impl --command "npm run build && npm run lint"

EOF
}

# Parse arguments
agent=""
slug=""
task_ref=""
spec_file=""
auto_start=0
initial_command=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec)
      spec_file="$2"
      shift 2
      ;;
    --auto-start)
      auto_start=1
      shift
      ;;
    --command)
      initial_command="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [ -z "$agent" ]; then
        agent="$1"
      elif [ -z "$slug" ]; then
        slug="$1"
      elif [ -z "$task_ref" ]; then
        task_ref="$1"
      else
        log_error "Too many positional arguments"
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate required arguments
if [ -z "$agent" ] || [ -z "$slug" ] || [ -z "$task_ref" ]; then
  log_error "Missing required arguments"
  usage
  exit 1
fi

# Setup directories
ensure_dirs
init_state

# Generate worker ID
worker_id=$(next_worker_id)
window_name="worker-${worker_id}-${agent}-${slug}"
log_file="${LOGS_DIR}/${worker_id}.log"
worker_json="${WORKERS_DIR}/${worker_id}.json"

# Create tmux window
log_info "Creating tmux window: ${window_name}"
tmux new-window -t sora-backend -n "${window_name}" -d -c "${REPO_ROOT}"
tmux set-window-option -t "sora-backend:${window_name}" remain-on-exit on

# Create worker JSON
log_info "Registering worker: ${worker_id}"
cat > "${worker_json}" <<EOF
{
  "worker_id": "${worker_id}",
  "agent": "${agent}",
  "tmux_window": "${window_name}",
  "status": "starting",
  "task_ref": "${task_ref}",
  "spec_path": "${spec_file}",
  "log_path": "${log_file}",
  "started_at": "$(iso8601_now)",
  "last_heartbeat": "$(iso8601_now)",
  "last_output_at": null,
  "owner": "controller"
}
EOF

# Prepare initial command
if [ $auto_start -eq 1 ]; then
  # Auto-start mode: inject claude command with spec
  if [ -z "$spec_file" ]; then
    initial_command="cd '${REPO_ROOT}' && claude '${task_ref}를 읽고 구현해줘'"
  else
    initial_command="cd '${REPO_ROOT}' && claude '${spec_file}를 읽고 구현해줘'"
  fi
  log_info "Auto-start enabled: will inject claude command"
elif [ -n "$initial_command" ]; then
  log_info "Custom command: ${initial_command}"
fi

# Send initial command if specified
if [ -n "$initial_command" ]; then
  log_info "Sending initial command to window"
  # Escape single quotes in command for tmux send-keys
  initial_command=${initial_command//\'/\'\\\'\'}
  tmux send-keys -t "sora-backend:${window_name}" "${initial_command}" Enter
fi

# Log the event
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Worker spawned: ${worker_id} (${agent}/${slug})" >> "${log_file}"

# Update state.json
log_success "Worker spawned: ${worker_id}"
log_info "Window: sora-backend:${window_name}"
log_info "Log: ${log_file}"
log_info "State: ${worker_json}"

# Optional: Print JSON output for automation
if [ "${OUTPUT_JSON:-0}" = "1" ]; then
  cat "${worker_json}"
fi
```

- [ ] **Step 2: 권한 설정 및 문법 검증**

```bash
chmod +x scripts/orchestrator/spawn-worker
bash -n scripts/orchestrator/spawn-worker
```

Expected: 문법 에러 없음.

---

## Task 3: `list-workers` 구현

**Files:**
- Create: `scripts/orchestrator/list-workers`

- [ ] **Step 1: 스크립트 작성**

다음 내용으로 `scripts/orchestrator/list-workers`를 작성한다.

```bash
#!/bin/bash
# list-workers: List all registered workers and their status

set -euo pipefail

source "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
Usage: list-workers [OPTIONS]

List all registered workers and compare with actual tmux windows.

Options:
  --json               Output as JSON
  --help               Show this help message

EOF
}

output_json=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      output_json=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

ensure_dirs
init_state

# Get list of actual tmux windows
mapfile -t actual_windows < <(tmux list-windows -t sora-backend -F "#{window_name}" 2>/dev/null || echo "")

# Count workers
worker_count=$(find "${WORKERS_DIR}" -name "worker-*.json" 2>/dev/null | wc -l)

if [ $output_json -eq 1 ]; then
  # JSON output
  echo "{"
  echo "  \"worker_count\": ${worker_count},"
  echo "  \"workers\": ["

  first=1
  for worker_file in "${WORKERS_DIR}"/worker-*.json; do
    if [ ! -f "$worker_file" ]; then
      continue
    fi

    if [ $first -eq 0 ]; then
      echo ","
    fi
    cat "$worker_file"
    first=0
  done

  echo "  ],"
  echo "  \"actual_windows\": ["
  first=1
  for window in "${actual_windows[@]}"; do
    if [ $first -eq 0 ]; then
      echo ","
    fi
    echo "    \"${window}\""
    first=0
  done
  echo "  ]"
  echo "}"
else
  # Human-readable output
  log_info "Registered workers: ${worker_count}"

  if [ ${#actual_windows[@]} -gt 0 ]; then
    echo ""
    echo "tmux Windows:"
    for window in "${actual_windows[@]}"; do
      echo "  - ${window}"
    done
  fi

  echo ""
  echo "Worker Details:"
  for worker_file in "${WORKERS_DIR}"/worker-*.json; do
    if [ ! -f "$worker_file" ]; then
      continue
    fi

    worker_id=$(jq -r '.worker_id' "$worker_file" 2>/dev/null || echo "unknown")
    agent=$(jq -r '.agent' "$worker_file" 2>/dev/null || echo "unknown")
    status=$(jq -r '.status' "$worker_file" 2>/dev/null || echo "unknown")
    task_ref=$(jq -r '.task_ref' "$worker_file" 2>/dev/null || echo "unknown")

    echo "  ${worker_id}: ${agent} | ${task_ref} | status=${status}"
  done
fi
```

- [ ] **Step 2: 권한 및 검증**

```bash
chmod +x scripts/orchestrator/list-workers
bash -n scripts/orchestrator/list-workers
```

---

## Task 4: `capture-worker` 구현

**Files:**
- Create: `scripts/orchestrator/capture-worker`

- [ ] **Step 1: 스크립트 작성**

다음 내용으로 `scripts/orchestrator/capture-worker`를 작성한다.

```bash
#!/bin/bash
# capture-worker: Capture output from a specific worker window

set -euo pipefail

source "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
Usage: capture-worker [OPTIONS] <worker-id>

Capture recent output from a worker's tmux window.

Arguments:
  worker-id            Worker ID (e.g., worker-001)

Options:
  --lines N            Number of lines to capture (default: 50)
  --help               Show this help message

EOF
}

worker_id=""
lines=50

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lines)
      lines="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      worker_id="$1"
      shift
      ;;
  esac
done

if [ -z "$worker_id" ]; then
  log_error "Missing worker-id argument"
  usage
  exit 1
fi

ensure_dirs

# Get worker JSON to find tmux window name
worker_json="${WORKERS_DIR}/${worker_id}.json"
if [ ! -f "$worker_json" ]; then
  log_error "Worker not found: ${worker_id}"
  exit 1
fi

window_name=$(jq -r '.tmux_window' "$worker_json")
log_info "Capturing ${lines} lines from ${window_name}"

# Capture pane output
if tmux capture-pane -t "sora-backend:${window_name}" -p -S "-${lines}" 2>/dev/null; then
  log_success "Captured output from ${worker_id}"
else
  log_error "Failed to capture from ${window_name}"
  exit 1
fi
```

- [ ] **Step 2: 권한 및 검증**

```bash
chmod +x scripts/orchestrator/capture-worker
bash -n scripts/orchestrator/capture-worker
```

---

## Task 5: `mark-worker` 구현

**Files:**
- Create: `scripts/orchestrator/mark-worker`

- [ ] **Step 1: 스크립트 작성**

다음 내용으로 `scripts/orchestrator/mark-worker`를 작성한다.

```bash
#!/bin/bash
# mark-worker: Update worker status

set -euo pipefail

source "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
Usage: mark-worker [OPTIONS] <worker-id> <status> [reason]

Update worker status and record the transition.

Arguments:
  worker-id            Worker ID (e.g., worker-001)
  status               New status: done|blocked|failed|running
  reason               Optional reason (for blocked/failed)

Options:
  --help               Show this help message

EOF
}

worker_id=""
status=""
reason=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [ -z "$worker_id" ]; then
        worker_id="$1"
      elif [ -z "$status" ]; then
        status="$1"
      else
        reason="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$worker_id" ] || [ -z "$status" ]; then
  log_error "Missing required arguments"
  usage
  exit 1
fi

ensure_dirs

worker_json="${WORKERS_DIR}/${worker_id}.json"
if [ ! -f "$worker_json" ]; then
  log_error "Worker not found: ${worker_id}"
  exit 1
fi

# Update JSON
tmp_json=$(mktemp)
jq --arg status "$status" --arg reason "$reason" --arg timestamp "$(iso8601_now)" \
  '.status = $status | .last_heartbeat = $timestamp | if $reason != "" then .blocker_reason = $reason else . end' \
  "$worker_json" > "$tmp_json"

mv "$tmp_json" "$worker_json"
log_success "Worker marked: ${worker_id} status=${status}"

if [ -n "$reason" ]; then
  log_info "Reason: ${reason}"
fi
```

- [ ] **Step 2: 권한 및 검증**

```bash
chmod +x scripts/orchestrator/mark-worker
bash -n scripts/orchestrator/mark-worker
```

---

## Task 6: `recover-session` 구현

**Files:**
- Create: `scripts/orchestrator/recover-session`

- [ ] **Step 1: 스크립트 작성**

다음 내용으로 `scripts/orchestrator/recover-session`를 작성한다.

```bash
#!/bin/bash
# recover-session: Validate and recover orchestration state

set -euo pipefail

source "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
Usage: recover-session [OPTIONS]

Validate .orchestrator state against actual tmux windows and normalize.

Options:
  --auto-fix          Automatically fix state mismatches
  --help              Show this help message

EOF
}

auto_fix=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-fix)
      auto_fix=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

ensure_dirs
init_state

log_info "Starting session recovery..."

# Get actual tmux windows
mapfile -t actual_windows < <(tmux list-windows -t sora-backend -F "#{window_name}" 2>/dev/null || true)

# Check registered workers
issues=0
for worker_file in "${WORKERS_DIR}"/worker-*.json; do
  if [ ! -f "$worker_file" ]; then
    continue
  fi

  worker_id=$(jq -r '.worker_id' "$worker_file")
  window_name=$(jq -r '.tmux_window' "$worker_file")
  status=$(jq -r '.status' "$worker_file")

  # Check if window exists
  window_found=0
  for actual_window in "${actual_windows[@]}"; do
    if [ "$actual_window" = "$window_name" ]; then
      window_found=1
      break
    fi
  done

  if [ $window_found -eq 0 ]; then
    log_warn "Window missing for ${worker_id} (${window_name})"
    ((issues++))

    if [ $auto_fix -eq 1 ]; then
      # Mark as stale
      tmp_json=$(mktemp)
      jq '.status = "stale"' "$worker_file" > "$tmp_json"
      mv "$tmp_json" "$worker_file"
      log_info "Marked ${worker_id} as stale"
    fi
  fi
done

log_info "Recovery check complete: ${issues} issues found"

if [ $issues -eq 0 ]; then
  log_success "Session state is healthy"
  exit 0
else
  log_warn "Run with --auto-fix to normalize issues"
  exit 1
fi
```

- [ ] **Step 2: 권한 및 검증**

```bash
chmod +x scripts/orchestrator/recover-session
bash -n scripts/orchestrator/recover-session
```

---

## Task 7: 통합 테스트

**Files:**
- Reference: `scripts/orchestrator/*`
- Reference: `docs/operations/tmux-orchestration.md`

- [ ] **Step 1: tmux 세션 초기화**

```bash
# 기존 세션 있으면 제거 (테스트 환경)
tmux kill-session -t sora-backend 2>/dev/null || true

# 새 세션 생성
tmux new-session -d -s sora-backend -c "$(pwd)"
```

- [ ] **Step 2: 각 script 실행 테스트**

```bash
# 1. spawn-worker (자동 트리거 없음)
scripts/orchestrator/spawn-worker codex routes task-1
sleep 1

# 2. list-workers
scripts/orchestrator/list-workers

# 3. capture-worker
scripts/orchestrator/capture-worker worker-001 --lines 10

# 4. mark-worker
scripts/orchestrator/mark-worker worker-001 running

# 5. recover-session
scripts/orchestrator/recover-session
```

Expected: 모든 script가 에러 없이 실행되고, worker가 등록되며 상태가 관리된다.

- [ ] **Step 3: auto-start 테스트 (선택)**

```bash
# WSL에서만 동작 (Claude 설치 필수)
scripts/orchestrator/spawn-worker codex auth auth-impl --auto-start
```

---

## Task 8: 문서 및 커밋

**Files:**
- Modify: `docs/operations/tmux-orchestration.md`
- Modify: `docs/current.md`
- Create: `.orchestrator/.gitkeep` (디렉터리 유지용)

- [ ] **Step 1: 운영 문서에 helper script 사용 예시 추가**

`docs/operations/tmux-orchestration.md`의 끝에 다음 섹션을 추가한다.

```md
## Helper Script 사용법

### spawn-worker

워커 생성 (수동):
```bash
scripts/orchestrator/spawn-worker codex routes task-1
```

워커 생성 + 자동 시작:
```bash
scripts/orchestrator/spawn-worker codex routes task-1 \
  --spec "docs/tasks/2026-03-31-routes.md" \
  --auto-start
```

### list-workers

등록된 워커 확인:
```bash
scripts/orchestrator/list-workers
```

JSON 출력:
```bash
scripts/orchestrator/list-workers --json
```

### capture-worker

워커 출력 캡처:
```bash
scripts/orchestrator/capture-worker worker-001 --lines 100
```

### mark-worker

워커 상태 업데이트:
```bash
scripts/orchestrator/mark-worker worker-001 done
scripts/orchestrator/mark-worker worker-001 blocked "DB 연결 필요"
```

### recover-session

세션 상태 복구:
```bash
scripts/orchestrator/recover-session
scripts/orchestrator/recover-session --auto-fix
```

## .orchestrator 상태 파일 구조

### state.json 예시

```json
{
  "session_id": "sora-backend",
  "repo_path": "/mnt/d/Projects/sora/sora-backend",
  "control_window": "control",
  "active_spec": "docs/tasks/2026-03-31-routes.md",
  "controller": {
    "agent": "claude",
    "status": "running",
    "last_heartbeat": "2026-03-31T15:35:00+09:00"
  },
  "workers": ["worker-001", "worker-002"]
}
```

### worker-*.json 예시

```json
{
  "worker_id": "worker-001",
  "agent": "codex",
  "tmux_window": "worker-001-codex-routes",
  "status": "running",
  "task_ref": "task-1",
  "spec_path": "docs/tasks/2026-03-31-routes.md",
  "log_path": ".orchestrator/logs/worker-001.log",
  "started_at": "2026-03-31T15:35:00+09:00",
  "last_heartbeat": "2026-03-31T15:40:00+09:00",
  "last_output_at": "2026-03-31T15:40:00+09:00",
  "owner": "controller"
}
```
```

- [ ] **Step 2: `.orchestrator/.gitkeep` 생성**

```bash
touch .orchestrator/.gitkeep
```

- [ ] **Step 3: docs/current.md 갱신**

`## 하네스 상태` 섹션을 다음과 같이 갱신한다.

```md
## 하네스 상태
- 상태: done
- 현재 담당: 사람
- 활성 스펙: 없음
- Claude 재판단 필요: 없음
```

`## 작업 체크리스트` → `### 완료`에 다음을 추가한다.

```md
- [x] tmux 오케스트레이션 2단계 helper script 구현 (spawn-worker, list-workers, capture-worker, mark-worker, recover-session)
- [x] spawn-worker --auto-start 옵션으로 자동 트리거 지원
```

- [ ] **Step 4: 커밋**

```bash
git add scripts/orchestrator/ \
        .orchestrator/.gitkeep \
        docs/operations/tmux-orchestration.md \
        docs/current.md

git commit -m "tmux 오케스트레이션 2단계 구현: helper script 추가" \
  -m "- spawn-worker: 워커 생성 + 초기 명령 주입 (--auto-start 지원)
 - list-workers: 등록된 워커와 tmux window 상태 조회
 - capture-worker: 워커 출력 캡처 (복구/디버깅 용)
 - mark-worker: 워커 상태 전이 기록
 - recover-session: 세션 상태 복구 및 정규화
 - 공통 라이브러리 (lib.sh): 디렉터리, 상태 파일, 로깅 함수
 - 운영 문서에 사용 예시 및 상태 파일 구조 추가"
```

---

## 완료 기준

2단계가 완료되려면 아래 모든 조건을 만족해야 한다.

- [ ] 5개 script 모두 `bash -n` 문법 검증 통과
- [ ] 각 script가 `--help` 출력 지원
- [ ] `spawn-worker` --auto-start 옵션 구현 완료
- [ ] 통합 테스트: 5개 script 실행 모두 성공
- [ ] `.orchestrator/` 상태 파일 예시가 문서에 포함됨
- [ ] 커밋 1개로 정리됨 (GitHub issue와 연결)
- [ ] PR merge, issue close, 로컬/원격 브랜치 정리 완료
- [ ] `docs/current.md`가 2단계 완료 상태로 갱신됨

---

## 3단계로 진행하기

2단계 검증이 완료되면 다음 단계로:

```md
# Task: tmux 오케스트레이션 3단계 - skill 연결

목표: `start-harness` 또는 별도 오케스트레이션 skill이 helper script를 호출하도록 통합

시작: docs/superpowers/plans/2026-03-31-tmux-orchestration-phase3.md 작성 후 `/start-harness` 실행
```
