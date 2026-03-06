#!/bin/bash
# Tests for setup.sh git initialization behavior
# Usage: bash tests/test_setup_git.sh

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

# --- Test 1: New setup initializes git repo in knowledge directory ---

test_git_init_new_setup() {
  local test_name="New setup initializes git repo"
  setup_test_env "$test_name"
  local ok=0

  # Pipe: knowledge dir path, registry name (default), language (default en)
  printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

  # Knowledge dir should be a git repository
  if ! git -C "$TEST_KNOWLEDGE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "  FAIL: $TEST_KNOWLEDGE_DIR should be a git repository"
    ok=1
  fi

  # Should have at least 1 commit
  if [ "$ok" -eq 0 ]; then
    local commit_count
    commit_count="$(git -C "$TEST_KNOWLEDGE_DIR" rev-list --count HEAD 2>/dev/null || echo 0)"
    if [ "$commit_count" -lt 1 ]; then
      echo "  FAIL: Should have at least 1 commit, got $commit_count"
      ok=1
    fi
  fi

  # Template files should be tracked
  if [ "$ok" -eq 0 ]; then
    local tracked
    tracked="$(git -C "$TEST_KNOWLEDGE_DIR" ls-files)"
    if ! grep -q "default/meta/INDEX.md" <<<"$tracked"; then
      echo "  FAIL: default/meta/INDEX.md should be tracked"
      ok=1
    fi
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: --force skips existing git repo ---

test_git_init_force_skip() {
  local test_name="--force skips existing git repo"
  setup_test_env "$test_name"
  local ok=0

  # First: normal setup to create knowledge dir with git repo
  printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

  # Record the HEAD commit before --force
  local head_before
  head_before="$(git -C "$TEST_KNOWLEDGE_DIR" rev-parse HEAD 2>/dev/null)"

  # Pre-set env vars in bashrc (so --force can read them)
  echo "export KAIZEN_CLI_DIR=\"$KAIZEN_CLI_DIR\"" >> "$TEST_BASHRC"
  echo "export KAIZEN_KNOWLEDGE_DIR=\"$TEST_KNOWLEDGE_DIR\"" >> "$TEST_BASHRC"

  # Run --force
  HOME="$TEST_HOME" SHELL=/bin/bash KAIZEN_CLI_DIR="$KAIZEN_CLI_DIR" KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" \
    bash "$KAIZEN_CLI_DIR/setup.sh" --force > /dev/null 2>&1 || true

  # HEAD should not have changed (no new commit)
  local head_after
  head_after="$(git -C "$TEST_KNOWLEDGE_DIR" rev-parse HEAD 2>/dev/null)"
  if [ "$head_before" != "$head_after" ]; then
    echo "  FAIL: HEAD should not change after --force (before=$head_before, after=$head_after)"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: Pre-existing user git repo is not re-initialized ---

test_git_init_preserves_user_repo() {
  local test_name="Pre-existing user git repo is preserved"
  setup_test_env "$test_name"
  local ok=0

  # Pre-create knowledge dir with user's own git repo and custom commit
  mkdir -p "$TEST_KNOWLEDGE_DIR"
  git -C "$TEST_KNOWLEDGE_DIR" init -q
  echo "user data" > "$TEST_KNOWLEDGE_DIR/notes.md"
  git -C "$TEST_KNOWLEDGE_DIR" add -A
  git -C "$TEST_KNOWLEDGE_DIR" -c commit.gpgSign=false commit -q -m "User's own commit"
  local original_hash
  original_hash="$(git -C "$TEST_KNOWLEDGE_DIR" rev-parse HEAD)"

  # Run setup
  printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

  # Original commit should still be the first commit
  local first_hash
  first_hash="$(git -C "$TEST_KNOWLEDGE_DIR" rev-list --max-parents=0 HEAD)"
  if [ "$first_hash" != "$original_hash" ]; then
    echo "  FAIL: Original user commit should be preserved"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== setup.sh git initialization tests ==="
echo ""

test_git_init_new_setup
test_git_init_force_skip
test_git_init_preserves_user_repo

print_results
