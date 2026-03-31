#!/bin/bash
# test-tmux-integration.sh: tmux orchestration integration tests with live session checks

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HELPER_DIR="$REPO_ROOT/scripts/orchestrator"

source "$HELPER_DIR/lib.sh"

CLAUDE_SKILL_ROOT="$HOME/.claude/skills/start-harness"
CODEX_SKILL_ROOT="$HOME/.codex/skills/start-harness"
PACK_SKILL_ROOT="$(readlink -f "$CLAUDE_SKILL_ROOT" 2>/dev/null || true)"
PROBE_PATH=""

if [ -x "$CLAUDE_SKILL_ROOT/scripts/probe.sh" ]; then
  PROBE_PATH="$CLAUDE_SKILL_ROOT/scripts/probe.sh"
elif [ -x "$CODEX_SKILL_ROOT/scripts/probe.sh" ]; then
  PROBE_PATH="$CODEX_SKILL_ROOT/scripts/probe.sh"
fi

pass=0
fail=0
created_session=0
cleanup_worker_id=""
cleanup_window=""
cleanup_slug="integration-smoke"
cleanup_task_ref="integration-smoke-task"
cleanup_log_prefix=""
test_queue_id=""

ok() {
  echo "[PASS] $1"
  pass=$((pass + 1))
}

fail_test() {
  echo "[FAIL] $1"
  fail=$((fail + 1))
}

remove_queue_item_by_id() {
  local queue_id="$1"
  if [ -z "$queue_id" ] || [ ! -f "$QUEUE_FILE" ]; then
    return
  fi

  local tmp_json
  tmp_json="$(mktemp)"
  jq --arg queue_id "$queue_id" 'if has("queue") then .queue |= map(select(.id != $queue_id)) else . end' "$QUEUE_FILE" > "$tmp_json"
  mv "$tmp_json" "$QUEUE_FILE"
}

cleanup() {
  remove_queue_item_by_id "$test_queue_id"

  if [ -n "$cleanup_window" ]; then
    tmux kill-window -t "${SESSION_NAME}:${cleanup_window}" 2>/dev/null || true
  fi

  if [ -n "$cleanup_worker_id" ]; then
    rm -f "${WORKERS_DIR}/${cleanup_worker_id}.json"
  fi

  if [ -n "$cleanup_worker_id" ] && [ -f "$STATE_FILE" ]; then
    local tmp_json
    tmp_json="$(mktemp)"
    jq --arg worker_id "$cleanup_worker_id" '.workers |= map(select(.worker_id != $worker_id))' "$STATE_FILE" > "$tmp_json"
    mv "$tmp_json" "$STATE_FILE"
  fi

  if [ -n "$cleanup_log_prefix" ]; then
    rm -f "${cleanup_log_prefix}.log" \
      "${cleanup_log_prefix}-cmd.sh" \
      "${cleanup_log_prefix}-task.txt"
  fi

  if [ "$created_session" -eq 1 ]; then
    tmux kill-session -t "${SESSION_NAME}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

ensure_tmux_session() {
  ensure_dirs
  init_state

  if ! tmux_session_exists; then
    tmux new-session -d -s "${SESSION_NAME}" -c "${REPO_ROOT}"
    tmux rename-window -t "${SESSION_NAME}:0" control
    created_session=1
  fi
}

assert_contract_markers() {
  local file="$1"
  local label="$2"
  local markers=(
    "## Minimal Bootstrap Context"
    "## Mode-Aware GitHub Gate"
    "## Downstream Ownership"
  )

  for marker in "${markers[@]}"; do
    if grep -Fq "$marker" "$file"; then
      ok "${label}: contains '${marker}'"
    else
      fail_test "${label}: missing '${marker}'"
    fi
  done
}

echo "=== tmux orchestration integration tests ==="

ensure_tmux_session

if [ -d "$CLAUDE_SKILL_ROOT" ]; then
  ok "Claude start-harness install exists at ${CLAUDE_SKILL_ROOT}"
else
  fail_test "Claude start-harness install missing at ${CLAUDE_SKILL_ROOT}"
fi

if [ -d "$CODEX_SKILL_ROOT" ]; then
  ok "Codex start-harness install exists at ${CODEX_SKILL_ROOT}"
else
  fail_test "Codex start-harness install missing at ${CODEX_SKILL_ROOT}"
fi

if [ -n "$PACK_SKILL_ROOT" ] && [ -d "$PACK_SKILL_ROOT" ]; then
  ok "Resolved shared pack root: ${PACK_SKILL_ROOT}"
else
  fail_test "Unable to resolve shared pack root from ${CLAUDE_SKILL_ROOT}"
fi

if [ -n "$PROBE_PATH" ]; then
  probe_output="$("$PROBE_PATH" 2>/dev/null)"

  if echo "$probe_output" | grep -q '^HAS_TMUX_ORCHESTRATION=1$'; then
    ok "probe.sh reports HAS_TMUX_ORCHESTRATION=1"
  else
    fail_test "probe.sh did not report HAS_TMUX_ORCHESTRATION=1"
  fi

  if echo "$probe_output" | grep -q '^TMUX_SESSION_READY=1$'; then
    ok "probe.sh reports TMUX_SESSION_READY=1"
  else
    fail_test "probe.sh did not report TMUX_SESSION_READY=1"
  fi

  if echo "$probe_output" | grep -q '^GH_READY='; then
    ok "probe.sh exposes GH_READY capability flag"
  else
    fail_test "probe.sh missing GH_READY capability flag"
  fi
else
  fail_test "probe.sh is not available from installed start-harness roots"
fi

helpers=("spawn-worker" "list-workers" "capture-worker" "mark-worker" "recover-session" "dashboard" "enqueue-worker")
for helper in "${helpers[@]}"; do
  if [ -x "$HELPER_DIR/$helper" ]; then
    ok "${helper} is executable"
  else
    fail_test "${helper} is missing or not executable"
  fi
done

assert_contract_markers "/mnt/c/Users/early/.codex/skills/start-harness/SKILL.md" "codex skill"
assert_contract_markers "/mnt/c/Users/early/.claude/skills/start-harness-pack/SKILL.md" "claude pack"
assert_contract_markers "/mnt/c/Users/early/.claude/skills/start-harness-pack/.agents/skills/start-harness/SKILL.md" "codex agent pack"

if grep -Fq "### 6. Worker dispatch for an active spec" "/mnt/c/Users/early/.claude/skills/start-harness-pack/SKILL.md"; then
  ok "claude pack documents worker dispatch path"
else
  fail_test "claude pack is missing worker dispatch path"
fi

if grep -Fq "### 6. Worker dispatch for an active spec" "/mnt/c/Users/early/.claude/skills/start-harness-pack/.agents/skills/start-harness/SKILL.md"; then
  ok "codex agent pack documents worker dispatch path"
else
  fail_test "codex agent pack is missing worker dispatch path"
fi

if output="$("$HELPER_DIR/spawn-worker" --help 2>&1 | head -1)" && echo "$output" | grep -q "Usage"; then
  ok "spawn-worker --help works"
else
  fail_test "spawn-worker --help failed"
fi

if output="$("$HELPER_DIR/list-workers" --help 2>&1 | head -1)" && echo "$output" | grep -q "Usage"; then
  ok "list-workers --help works"
else
  fail_test "list-workers --help failed"
fi

queue_before=0
if [ -f "$QUEUE_FILE" ]; then
  queue_before="$(jq '.queue | length' "$QUEUE_FILE" 2>/dev/null || echo 0)"
fi

enqueue_output="$(OUTPUT_JSON=1 "$HELPER_DIR/enqueue-worker" codex "$cleanup_slug" "$cleanup_task_ref" --priority 1 --spec docs/current.md)"
if echo "$enqueue_output" | jq empty >/dev/null 2>&1; then
  ok "enqueue-worker returns valid JSON"
else
  fail_test "enqueue-worker JSON output is invalid"
fi

test_queue_id="$(echo "$enqueue_output" | jq -r '.queue[] | select(.slug == "'"$cleanup_slug"'") | .id' | tail -1)"
if [ -n "$test_queue_id" ] && [ "$test_queue_id" != "null" ]; then
  ok "enqueue-worker registered the smoke task"
else
  fail_test "enqueue-worker did not register the smoke task"
fi

spawn_output="$(OUTPUT_JSON=1 "$HELPER_DIR/spawn-worker" --from-queue --command "echo integration-smoke-ok")"
if echo "$spawn_output" | jq empty >/dev/null 2>&1; then
  ok "spawn-worker --from-queue returns valid JSON"
else
  fail_test "spawn-worker --from-queue JSON output is invalid"
fi

cleanup_worker_id="$(echo "$spawn_output" | jq -r '.worker_id')"
cleanup_window="$(echo "$spawn_output" | jq -r '.tmux_window')"
cleanup_log_prefix="${LOGS_DIR}/${cleanup_worker_id}"
test_queue_id=""

if [ -n "$cleanup_worker_id" ] && [ "$cleanup_worker_id" != "null" ]; then
  ok "spawn-worker created worker ${cleanup_worker_id}"
else
  fail_test "spawn-worker did not return a worker id"
fi

sleep 1

list_output="$("$HELPER_DIR/list-workers" --json)"
if echo "$list_output" | jq empty >/dev/null 2>&1; then
  ok "list-workers --json returns valid JSON"
else
  fail_test "list-workers --json output is invalid"
fi

if echo "$list_output" | jq -e --arg worker_id "$cleanup_worker_id" '.workers | any(.worker_id == $worker_id)' >/dev/null 2>&1; then
  ok "list-workers includes the spawned worker"
else
  fail_test "list-workers does not include the spawned worker"
fi

capture_output="$("$HELPER_DIR/capture-worker" --lines 20 "$cleanup_worker_id")"
if echo "$capture_output" | grep -q "integration-smoke-ok"; then
  ok "capture-worker captured worker output"
else
  fail_test "capture-worker did not capture expected worker output"
fi

dashboard_output="$("$HELPER_DIR/dashboard" --json)"
if echo "$dashboard_output" | jq empty >/dev/null 2>&1; then
  ok "dashboard --json returns valid JSON"
else
  fail_test "dashboard --json output is invalid"
fi

if echo "$dashboard_output" | jq -e --arg worker_id "$cleanup_worker_id" '.workers | any(.id == $worker_id)' >/dev/null 2>&1; then
  ok "dashboard includes the spawned worker"
else
  fail_test "dashboard does not include the spawned worker"
fi

if "$HELPER_DIR/mark-worker" "$cleanup_worker_id" done integration-smoke-complete >/dev/null 2>&1; then
  ok "mark-worker can update worker status"
else
  fail_test "mark-worker failed to update worker status"
fi

if jq -e --arg worker_id "$cleanup_worker_id" '.workers | any(.worker_id == $worker_id and .status == "done")' "$STATE_FILE" >/dev/null 2>&1; then
  ok "state.json stays in sync after mark-worker"
else
  fail_test "state.json did not sync worker status after mark-worker"
fi

if "$HELPER_DIR/recover-session" --auto-fix >/dev/null 2>&1; then
  ok "recover-session --auto-fix succeeds with live tmux session"
else
  fail_test "recover-session --auto-fix failed"
fi

queue_after=0
if [ -f "$QUEUE_FILE" ]; then
  queue_after="$(jq '.queue | length' "$QUEUE_FILE" 2>/dev/null || echo 0)"
fi

if [ "$queue_after" -eq "$queue_before" ]; then
  ok "queue length returned to its original size"
else
  fail_test "queue length mismatch after spawn-from-queue: before=${queue_before}, after=${queue_after}"
fi

if cd "$REPO_ROOT" && npm run build >/dev/null 2>&1; then
  ok "npm run build passed"
else
  fail_test "npm run build failed"
fi

if cd "$REPO_ROOT" && npm run lint >/dev/null 2>&1; then
  ok "npm run lint passed"
else
  fail_test "npm run lint failed"
fi

if cd "$REPO_ROOT" && npm test -- --runInBand --passWithNoTests >/dev/null 2>&1; then
  ok "npm test -- --runInBand --passWithNoTests passed"
else
  fail_test "npm test -- --runInBand --passWithNoTests failed"
fi

echo ""
echo "Results: ${pass} passed, ${fail} failed"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
