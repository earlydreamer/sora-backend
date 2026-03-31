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

# Queue file path
QUEUE_FILE="${ORCHESTRATOR_DIR}/queue.json"

# Generate next queue item ID
next_queue_id() {
  local count
  if [ -f "${QUEUE_FILE}" ]; then
    count=$(jq '.queue | length' "${QUEUE_FILE}" 2>/dev/null || echo 0)
  else
    count=0
  fi
  printf "q-%03d" $((count + 1))
}

# queue_push: add an item to the queue
# Args: agent slug task_ref spec_path priority
queue_push() {
  local agent="$1"
  local slug="$2"
  local task_ref="$3"
  local spec_path="${4:-}"
  local priority="${5:-5}"
  local qid
  qid=$(next_queue_id)
  local enqueued_at
  enqueued_at=$(iso8601_now)

  if [ ! -f "${QUEUE_FILE}" ]; then
    echo '{"queue":[]}' > "${QUEUE_FILE}"
  fi

  local tmp_json
  tmp_json=$(mktemp)
  jq \
    --arg id "$qid" \
    --arg agent "$agent" \
    --arg slug "$slug" \
    --arg task_ref "$task_ref" \
    --arg spec_path "$spec_path" \
    --argjson priority "$priority" \
    --arg enqueued_at "$enqueued_at" \
    '.queue += [{
      "id": $id,
      "agent": $agent,
      "slug": $slug,
      "task_ref": $task_ref,
      "spec_path": $spec_path,
      "priority": $priority,
      "enqueued_at": $enqueued_at
    }] | .queue |= sort_by(.priority)' \
    "${QUEUE_FILE}" > "$tmp_json"
  mv "$tmp_json" "${QUEUE_FILE}"
}

# queue_pop: output first item as JSON and remove it from queue
queue_pop() {
  if [ ! -f "${QUEUE_FILE}" ]; then
    log_error "Queue file not found: ${QUEUE_FILE}"
    return 1
  fi

  local count
  count=$(jq '.queue | length' "${QUEUE_FILE}" 2>/dev/null || echo 0)
  if [ "$count" -eq 0 ]; then
    log_error "Queue is empty"
    return 1
  fi

  # Output the first item
  jq '.queue[0]' "${QUEUE_FILE}"

  # Remove the first item from queue
  local tmp_json
  tmp_json=$(mktemp)
  jq '.queue = .queue[1:]' "${QUEUE_FILE}" > "$tmp_json"
  mv "$tmp_json" "${QUEUE_FILE}"
}

# queue_list: output full queue.json
queue_list() {
  if [ ! -f "${QUEUE_FILE}" ]; then
    echo '{"queue":[]}'
    return
  fi
  cat "${QUEUE_FILE}"
}

export -f log_info log_success log_warn log_error
export -f ensure_dirs init_state next_worker_id iso8601_now validate_worker_json tmux_session_exists
export -f next_queue_id queue_push queue_pop queue_list
export REPO_ROOT ORCHESTRATOR_DIR STATE_FILE WORKERS_DIR LOGS_DIR QUEUE_FILE
