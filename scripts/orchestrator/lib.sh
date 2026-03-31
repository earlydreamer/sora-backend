#!/bin/bash
# Common functions for orchestrator scripts

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions — all write to stderr so stdout stays clean for data output
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $*" >&2
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*" >&2
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
RUNTIME_DIR="${ORCHESTRATOR_DIR}/runtime"

# Session name derived from repo root basename — not hardcoded [M1]
SESSION_NAME="$(basename "${REPO_ROOT}")"

# Ensure orchestrator directories exist
ensure_dirs() {
  mkdir -p "${ORCHESTRATOR_DIR}" "${WORKERS_DIR}" "${LOGS_DIR}" "${RUNTIME_DIR}/codex-home"
}

# Initialize state.json if not exists
init_state() {
  if [ ! -f "${STATE_FILE}" ]; then
    jq -n \
      --arg session_id "${SESSION_NAME}" \
      --arg repo_path "${REPO_ROOT}" \
      --arg ts "$(date -u +'%Y-%m-%dT%H:%M:%S%z')" \
      '{
        session_id: $session_id,
        repo_path: $repo_path,
        control_window: "control",
        active_spec: "",
        controller: {
          agent: "unknown",
          status: "idle",
          last_heartbeat: $ts
        },
        workers: []
      }' > "${STATE_FILE}"
    log_info "Initialized state.json"
  fi
}

# Upsert a worker entry in state.json so summary state stays aligned with worker JSON files
upsert_state_worker() {
  local worker_id="$1"
  local agent="${2:-unknown}"
  local tmux_window="${3:-}"
  local status="${4:-starting}"

  init_state

  local tmp_json
  tmp_json=$(mktemp)
  jq \
    --arg worker_id "$worker_id" \
    --arg agent "$agent" \
    --arg tmux_window "$tmux_window" \
    --arg status "$status" \
    '
    .workers = (.workers // [])
    | .workers |= (
        if any(.[]?; .worker_id == $worker_id) then
          map(
            if .worker_id == $worker_id then
              .status = $status
              | if $agent != "" then .agent = $agent else . end
              | if $tmux_window != "" then .tmux_window = $tmux_window else . end
            else
              .
            end
          )
        else
          . + [{
            worker_id: $worker_id,
            agent: $agent,
            tmux_window: $tmux_window,
            status: $status
          }]
        end
      )
    ' "${STATE_FILE}" > "$tmp_json"
  mv "$tmp_json" "${STATE_FILE}"
}

# Generate next worker ID using max existing suffix + 1 to avoid races and reuse [C2]
next_worker_id() {
  local max=0
  local n
  for f in "${WORKERS_DIR}"/worker-*.json; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .json | grep -oE '[0-9]+$' || true)
    [ -n "$n" ] && [ "$n" -gt "$max" ] && max="$n"
  done
  printf "worker-%03d" $((max + 1))
}

# Format ISO 8601 timestamp
iso8601_now() {
  date -u +'%Y-%m-%dT%H:%M:%S%z'
}

# Validate worker JSON format — call before processing any worker file [M2]
validate_worker_json() {
  local worker_file="$1"
  if ! jq empty "${worker_file}" 2>/dev/null; then
    log_error "Invalid JSON: ${worker_file}"
    return 1
  fi
}

# Get session status from tmux
tmux_session_exists() {
  tmux has-session -t "${SESSION_NAME}" 2>/dev/null
}

# Queue file path
QUEUE_FILE="${ORCHESTRATOR_DIR}/queue.json"

# Generate next queue item ID using max suffix + 1 [C2-style fix for queue]
next_queue_id() {
  local max=0
  local n
  if [ -f "${QUEUE_FILE}" ]; then
    while IFS= read -r id; do
      n=$(echo "$id" | grep -oE '[0-9]+$' || true)
      [ -n "$n" ] && [ "$n" -gt "$max" ] && max="$n"
    done < <(jq -r '.queue[].id // empty' "${QUEUE_FILE}" 2>/dev/null || true)
  fi
  printf "q-%03d" $((max + 1))
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
  # Use jq --arg to safely escape all string fields [L1/H4]
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
# Returns the item on stdout; logs to stderr [H2-style]
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

  # Output the first item to stdout
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

codex_source_home() {
  printf '%s\n' "${CODEX_HOME:-${HOME}/.codex}"
}

codex_worker_home_dir() {
  local worker_id="$1"
  printf '%s/codex-home/%s\n' "${RUNTIME_DIR}" "${worker_id}"
}

prepare_codex_worker_home() {
  local worker_id="$1"
  local worker_home
  worker_home="$(codex_worker_home_dir "${worker_id}")"
  mkdir -p "${worker_home}" "${worker_home}/sessions" "${worker_home}/log" "${worker_home}/tmp"

  local source_home
  source_home="$(codex_source_home)"
  local shared_entries=(
    "auth.json"
    ".credentials.json"
    "config.toml"
    "managed_config.toml"
    "skills"
    "plugins"
    "memories"
    "models_cache.json"
    "vendor_imports"
    "rules"
    "AGENTS.md"
  )

  local entry
  for entry in "${shared_entries[@]}"; do
    if [ -e "${source_home}/${entry}" ] && [ ! -e "${worker_home}/${entry}" ]; then
      ln -s "${source_home}/${entry}" "${worker_home}/${entry}"
    fi
  done

  printf '%s\n' "${worker_home}"
}

export -f log_info log_success log_warn log_error
export -f ensure_dirs init_state upsert_state_worker next_worker_id iso8601_now validate_worker_json tmux_session_exists
export -f next_queue_id queue_push queue_pop queue_list
export -f codex_source_home codex_worker_home_dir prepare_codex_worker_home
export REPO_ROOT ORCHESTRATOR_DIR STATE_FILE WORKERS_DIR LOGS_DIR RUNTIME_DIR QUEUE_FILE SESSION_NAME
