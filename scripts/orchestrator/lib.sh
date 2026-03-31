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
