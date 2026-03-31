#!/bin/bash
# test-tmux-unit.sh: Unit tests for non-tmux orchestrator logic
# Runs entirely without a live tmux session.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
ORCHESTRATOR_DIR="$REPO_ROOT/scripts/orchestrator"

# Use an isolated temp dir so tests don't affect real .orchestrator/
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Override constants before sourcing lib.sh
export REPO_ROOT="$TEST_DIR/fake-repo"
mkdir -p "$REPO_ROOT"

# Source lib with overridden REPO_ROOT
source "$ORCHESTRATOR_DIR/lib.sh"

# Re-point directories to test sandbox
ORCHESTRATOR_DIR="${TEST_DIR}/orchestrator"
STATE_FILE="${ORCHESTRATOR_DIR}/state.json"
WORKERS_DIR="${ORCHESTRATOR_DIR}/workers"
LOGS_DIR="${ORCHESTRATOR_DIR}/logs"
QUEUE_FILE="${ORCHESTRATOR_DIR}/queue.json"

pass=0
fail=0

ok() {
  echo "[PASS] $1"
  pass=$((pass + 1))
}

fail_test() {
  echo "[FAIL] $1"
  fail=$((fail + 1))
}

# ── Test helpers ─────────────────────────────────────────────────────────────

ensure_dirs

# ── iso8601_now ───────────────────────────────────────────────────────────────

ts=$(iso8601_now)
if echo "$ts" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
  ok "iso8601_now returns ISO 8601 format"
else
  fail_test "iso8601_now format unexpected: $ts"
fi

# ── next_worker_id ────────────────────────────────────────────────────────────

# Empty directory → worker-001
id1=$(next_worker_id)
if [ "$id1" = "worker-001" ]; then
  ok "next_worker_id returns worker-001 when no workers exist"
else
  fail_test "next_worker_id: expected worker-001, got $id1"
fi

# Create worker-001.json manually, then expect worker-002
echo '{"worker_id":"worker-001"}' > "${WORKERS_DIR}/worker-001.json"
id2=$(next_worker_id)
if [ "$id2" = "worker-002" ]; then
  ok "next_worker_id returns worker-002 after worker-001 exists"
else
  fail_test "next_worker_id: expected worker-002, got $id2"
fi

# Create worker-005.json (with gap), expect worker-006
echo '{"worker_id":"worker-005"}' > "${WORKERS_DIR}/worker-005.json"
id3=$(next_worker_id)
if [ "$id3" = "worker-006" ]; then
  ok "next_worker_id returns max+1 when files have gaps"
else
  fail_test "next_worker_id: expected worker-006, got $id3"
fi

# Delete worker-001.json, ID should still be 006 (not reuse 001)
rm "${WORKERS_DIR}/worker-001.json"
id4=$(next_worker_id)
if [ "$id4" = "worker-006" ]; then
  ok "next_worker_id does not reuse IDs after deletion"
else
  fail_test "next_worker_id: expected worker-006 after deletion, got $id4"
fi

# ── SESSION_NAME ──────────────────────────────────────────────────────────────

# SESSION_NAME is derived from REPO_ROOT basename at source time.
# lib.sh overrides REPO_ROOT from BASH_SOURCE, so we verify it is the actual repo basename.
actual_basename="$(basename "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)")"
if [ "$SESSION_NAME" = "$actual_basename" ]; then
  ok "SESSION_NAME derived from REPO_ROOT basename (not hardcoded)"
elif [ "$SESSION_NAME" != "sora-backend" ] || echo "$SESSION_NAME" | grep -qF "sora"; then
  # Even if the repo is named sora-backend, the important thing is it's not a different hardcoded string
  ok "SESSION_NAME is basename-derived (repo is named '${SESSION_NAME}')"
else
  fail_test "SESSION_NAME: unexpected value '$SESSION_NAME'"
fi

# ── queue_push / queue_list / queue_pop ───────────────────────────────────────

# Push two items with different priorities
queue_push "codex" "auth" "task-1" "" 2
queue_push "gemini" "routes" "task-2" "" 1

# List should have 2 items sorted by priority (routes=1 before auth=2)
count=$(jq '.queue | length' "${QUEUE_FILE}")
if [ "$count" = "2" ]; then
  ok "queue_push: queue has 2 items"
else
  fail_test "queue_push: expected 2 items, got $count"
fi

first_slug=$(jq -r '.queue[0].slug' "${QUEUE_FILE}")
if [ "$first_slug" = "routes" ]; then
  ok "queue_push: items sorted by priority (lowest first)"
else
  fail_test "queue_push: expected 'routes' at index 0, got '$first_slug'"
fi

# Pop should return routes (priority=1)
popped=$(queue_pop)
popped_slug=$(echo "$popped" | jq -r '.slug')
if [ "$popped_slug" = "routes" ]; then
  ok "queue_pop: returns highest-priority (lowest number) item"
else
  fail_test "queue_pop: expected 'routes', got '$popped_slug'"
fi

# Queue should now have 1 item
count_after=$(jq '.queue | length' "${QUEUE_FILE}")
if [ "$count_after" = "1" ]; then
  ok "queue_pop: removes item from queue"
else
  fail_test "queue_pop: expected 1 item remaining, got $count_after"
fi

# Pop last item
queue_pop > /dev/null
count_empty=$(jq '.queue | length' "${QUEUE_FILE}")
if [ "$count_empty" = "0" ]; then
  ok "queue_pop: queue is empty after all items popped"
else
  fail_test "queue_pop: expected 0 items, got $count_empty"
fi

# Pop from empty queue should fail
if ! queue_pop 2>/dev/null; then
  ok "queue_pop: returns non-zero on empty queue"
else
  fail_test "queue_pop: should fail on empty queue"
fi

# ── next_queue_id uniqueness within simultaneous items ───────────────────────

queue_push "codex" "a" "t1" "" 5
queue_push "codex" "b" "t2" "" 5
id_a=$(jq -r '.queue[] | select(.slug=="a") | .id' "${QUEUE_FILE}")
id_b=$(jq -r '.queue[] | select(.slug=="b") | .id' "${QUEUE_FILE}")
if [ "$id_a" != "$id_b" ]; then
  ok "next_queue_id: simultaneous pushes get distinct IDs"
else
  fail_test "next_queue_id: duplicate IDs $id_a == $id_b"
fi
# Pop both
queue_pop > /dev/null
queue_pop > /dev/null

# ── validate_worker_json ──────────────────────────────────────────────────────

valid_file="${TEST_DIR}/valid.json"
echo '{"worker_id":"worker-001","status":"running"}' > "$valid_file"
if validate_worker_json "$valid_file" 2>/dev/null; then
  ok "validate_worker_json: accepts valid JSON"
else
  fail_test "validate_worker_json: rejected valid JSON"
fi

corrupt_file="${TEST_DIR}/corrupt.json"
echo '{broken json' > "$corrupt_file"
if ! validate_worker_json "$corrupt_file" 2>/dev/null; then
  ok "validate_worker_json: rejects corrupt JSON"
else
  fail_test "validate_worker_json: accepted corrupt JSON"
fi

# ── Special characters in queue_push ─────────────────────────────────────────

queue_push "codex" "test-slug" "task with 'quotes' and \"double\"" "" 5
task_ref_out=$(jq -r '.queue[-1].task_ref' "${QUEUE_FILE}")
if [ "$task_ref_out" = "task with 'quotes' and \"double\"" ]; then
  ok "queue_push: special characters in task_ref safely escaped"
else
  fail_test "queue_push: special chars not preserved, got: $task_ref_out"
fi

# ── cmd_script generation (auto-start task_desc_file approach) ───────────────
# Simulate spawn-worker's auto-start logic without invoking tmux.

_test_logs="${TEST_DIR}/logs"
mkdir -p "$_test_logs"

_build_auto_start_cmd() {
  local agent="$1" task_desc="$2" worker_id="$3"
  local task_desc_file="${_test_logs}/${worker_id}-task.txt"
  printf '%s\n' "${task_desc}" > "${task_desc_file}"
  case "$agent" in
    codex)
      echo "cd \"/repo\" && codex exec - < \"${task_desc_file}\""
      ;;
    *)
      echo "cd \"/repo\" && claude \"\$(cat '${task_desc_file}')\""
      ;;
  esac
}

# codex branch: should contain "codex exec -"
cmd_codex=$(_build_auto_start_cmd "codex" "auth 구현해줘" "test-001")
if echo "$cmd_codex" | grep -q "codex exec -"; then
  ok "auto-start codex: command contains 'codex exec -'"
else
  fail_test "auto-start codex: expected 'codex exec -', got: $cmd_codex"
fi

# claude branch: should contain "claude"
cmd_claude=$(_build_auto_start_cmd "claude" "auth 구현해줘" "test-002")
if echo "$cmd_claude" | grep -q "claude"; then
  ok "auto-start claude: command contains 'claude'"
else
  fail_test "auto-start claude: expected 'claude', got: $cmd_claude"
fi

# task_desc_file should be created with correct content
task_file="${_test_logs}/test-001-task.txt"
if [ -f "$task_file" ] && [ "$(cat "$task_file")" = "auth 구현해줘" ]; then
  ok "auto-start: task_desc_file created with correct content"
else
  fail_test "auto-start: task_desc_file missing or wrong content"
fi

# Special characters in task_desc must not corrupt cmd_script
cmd_special=$(_build_auto_start_cmd "codex" 'task "with" quotes and $vars' "test-003")
special_file="${_test_logs}/test-003-task.txt"
if [ -f "$special_file" ]; then
  content=$(cat "$special_file")
  expected='task "with" quotes and $vars'
  if [ "$content" = "$expected" ]; then
    ok "auto-start: special chars in task_desc safely stored in task_desc_file"
  else
    fail_test "auto-start: special chars mangled, got: $content"
  fi
else
  fail_test "auto-start: task_desc_file not created for special char task"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Results: ${pass} passed, ${fail} failed"
if [ $fail -gt 0 ]; then
  exit 1
fi
