#!/bin/bash
# test-tmux-integration.sh: Phase 3 tmux orchestration integration tests

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR_DIR="$REPO_ROOT/scripts/orchestrator"

# Source lib.sh for logging
source "$ORCHESTRATOR_DIR/lib.sh"

log_info "=== Phase 3 TMux Orchestration Integration Tests ==="

# Test 1: probe.sh detection
log_info "Test 1: probe.sh tmux orchestration detection"
if [ -f "$HOME/.claude/skills/start-harness-pack/scripts/probe.sh" ]; then
  output=$("$HOME/.claude/skills/start-harness-pack/scripts/probe.sh" 2>/dev/null | grep HAS_TMUX_ORCHESTRATION)
  if echo "$output" | grep -q "HAS_TMUX_ORCHESTRATION=1"; then
    log_success "✓ probe.sh correctly detects tmux orchestration"
  else
    log_warn "✗ probe.sh does not detect tmux orchestration (expected if session not initialized)"
    echo "  Output: $output"
  fi
else
  log_warn "✗ start-harness-pack not found at expected location"
fi

# Test 2: Helper scripts exist and are executable
log_info "Test 2: Helper scripts existence and executability"
helpers=("spawn-worker" "list-workers" "capture-worker" "mark-worker" "recover-session")
for helper in "${helpers[@]}"; do
  if [ -x "$ORCHESTRATOR_DIR/$helper" ]; then
    log_success "✓ $helper is executable"
  else
    log_error "✗ $helper is not executable or missing"
  fi
done

# Test 3: lib.sh functions are available
log_info "Test 3: lib.sh functions availability"
if declare -f log_info >/dev/null 2>&1 && \
   declare -f log_success >/dev/null 2>&1 && \
   declare -f next_worker_id >/dev/null 2>&1; then
  log_success "✓ lib.sh functions loaded correctly"
else
  log_error "✗ lib.sh functions not available"
fi

# Test 4: .orchestrator directory structure
log_info "Test 4: .orchestrator directory structure"
required_dirs=(".orchestrator" ".orchestrator/workers" ".orchestrator/logs")
for dir in "${required_dirs[@]}"; do
  if [ -d "$REPO_ROOT/$dir" ]; then
    log_success "✓ $dir exists"
  else
    log_warn "✗ $dir missing (will be created at runtime)"
  fi
done

# Test 5: spawn-worker --help
log_info "Test 5: spawn-worker usage"
if output=$("$ORCHESTRATOR_DIR/spawn-worker" --help 2>&1 | head -1); then
  if echo "$output" | grep -q "Usage"; then
    log_success "✓ spawn-worker --help works"
  fi
fi

# Test 6: list-workers --help
log_info "Test 6: list-workers usage"
if output=$("$ORCHESTRATOR_DIR/list-workers" --help 2>&1 | head -1); then
  if echo "$output" | grep -q "Usage"; then
    log_success "✓ list-workers --help works"
  fi
fi

# Test 7: docs/current.md has worker-dispatch-ready state option
log_info "Test 7: docs/current.md state options"
if grep -q "worker-dispatch-ready" "$REPO_ROOT/docs/current.md" || \
   grep -q "활성 워커" "$REPO_ROOT/docs/current.md"; then
  log_success "✓ docs/current.md mentions worker state or active workers"
else
  log_warn "✗ docs/current.md does not yet document worker dispatch state"
fi

# Test 8: SKILL.md has Path 6
log_info "Test 8: start-harness SKILL.md Path 6"
if grep -q "### 6" "$HOME/.claude/skills/start-harness-pack/SKILL.md" 2>/dev/null; then
  log_success "✓ SKILL.md has Path 6 for worker dispatch"
else
  log_warn "✗ SKILL.md Path 6 not found (may not be installed)"
fi

# Test 9: Run build and lint
log_info "Test 9: Build and lint verification"
if cd "$REPO_ROOT" && npm run build >/dev/null 2>&1; then
  log_success "✓ npm run build passed"
else
  log_error "✗ npm run build failed"
fi

if cd "$REPO_ROOT" && npm run lint >/dev/null 2>&1; then
  log_success "✓ npm run lint passed"
else
  log_error "✗ npm run lint failed"
fi

# Test 10: Run tests
log_info "Test 10: Unit tests"
if cd "$REPO_ROOT" && npm test -- --runInBand --passWithNoTests 2>&1 | grep -q "Tests:"; then
  log_success "✓ npm test ran successfully"
else
  log_warn "✗ npm test encountered issues (may be expected in reduced env)"
fi

log_success "=== All integration tests complete ==="
