#!/bin/bash
# Tests for setup.sh --force flag behavior
# Usage: bash tests/test_setup_force.sh

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

# --- Test 1: --force with existing registry (no .lang) → backward compatible ---

test_force_backward_compat() {
  local test_name="--force backward compat (no .lang)"
  setup_test_env "$test_name"
  local ok=0

  # Pre-create registry without .lang (simulates pre-existing setup)
  mkdir -p "$TEST_KNOWLEDGE_DIR/default/meta" "$TEST_KNOWLEDGE_DIR/default/projects"
  echo "existing content" > "$TEST_KNOWLEDGE_DIR/default/meta/INDEX.md"

  # Pre-set env vars in bashrc (so --force can read them)
  echo "export KAIZEN_CLI_DIR=\"$KAIZEN_CLI_DIR\"" >> "$TEST_BASHRC"
  echo "export KAIZEN_KNOWLEDGE_DIR=\"$TEST_KNOWLEDGE_DIR\"" >> "$TEST_BASHRC"

  HOME="$TEST_HOME" SHELL=/bin/bash KAIZEN_CLI_DIR="$KAIZEN_CLI_DIR" KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" \
    bash "$KAIZEN_CLI_DIR/setup.sh" --force > /dev/null 2>&1 || true

  # .lang should now be created with 'en' default
  assert_file_exists "$TEST_KNOWLEDGE_DIR/default/.lang" \
    ".lang file should be created by --force" || ok=1
  if [ "$ok" -eq 0 ]; then
    local lang_val
    lang_val="$(cat "$TEST_KNOWLEDGE_DIR/default/.lang")"
    if [ "$lang_val" != "en" ]; then
      echo "  FAIL: .lang should default to 'en', got '$lang_val'"
      ok=1
    fi
  fi

  # Existing file should NOT be overwritten
  assert_file_contains "$TEST_KNOWLEDGE_DIR/default/meta/INDEX.md" \
    "existing content" \
    "Existing INDEX.md should be preserved" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: --force with existing .lang=ja → preserves language ---

test_force_preserves_lang() {
  local test_name="--force preserves existing .lang"
  setup_test_env "$test_name"
  local ok=0

  # Pre-create registry with .lang=ja
  mkdir -p "$TEST_KNOWLEDGE_DIR/default/meta" "$TEST_KNOWLEDGE_DIR/default/projects"
  echo "ja" > "$TEST_KNOWLEDGE_DIR/default/.lang"
  echo "existing" > "$TEST_KNOWLEDGE_DIR/default/meta/INDEX.md"

  echo "export KAIZEN_CLI_DIR=\"$KAIZEN_CLI_DIR\"" >> "$TEST_BASHRC"
  echo "export KAIZEN_KNOWLEDGE_DIR=\"$TEST_KNOWLEDGE_DIR\"" >> "$TEST_BASHRC"

  HOME="$TEST_HOME" SHELL=/bin/bash KAIZEN_CLI_DIR="$KAIZEN_CLI_DIR" KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" \
    bash "$KAIZEN_CLI_DIR/setup.sh" --force > /dev/null 2>&1 || true

  # .lang should remain 'ja' (not overwritten)
  local lang_val
  lang_val="$(cat "$TEST_KNOWLEDGE_DIR/default/.lang")"
  if [ "$lang_val" != "ja" ]; then
    echo "  FAIL: .lang should remain 'ja', got '$lang_val'"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: --force removes legacy global kaizen commands ---

test_force_removes_legacy_commands() {
  local test_name="--force removes legacy global kaizen commands"
  setup_test_env "$test_name"
  local ok=0

  # First: normal setup to create knowledge dir
  printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

  # Simulate legacy global commands
  mkdir -p "$TEST_HOME/.claude/commands"
  ln -s "$KAIZEN_CLI_DIR/framework/.claude/commands/kaizen-suggest-next.md" \
    "$TEST_HOME/.claude/commands/kaizen-suggest-next.md"
  ln -s "$KAIZEN_CLI_DIR/framework/.claude/commands/kaizen-reflect-learning.md" \
    "$TEST_HOME/.claude/commands/kaizen-reflect-learning.md"

  echo "export KAIZEN_CLI_DIR=\"$KAIZEN_CLI_DIR\"" >> "$TEST_BASHRC"
  echo "export KAIZEN_KNOWLEDGE_DIR=\"$TEST_KNOWLEDGE_DIR\"" >> "$TEST_BASHRC"

  # Run --force
  local output
  output=$(HOME="$TEST_HOME" SHELL=/bin/bash KAIZEN_CLI_DIR="$KAIZEN_CLI_DIR" KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" \
    bash "$KAIZEN_CLI_DIR/setup.sh" --force 2>&1) || true

  # Legacy commands should be removed
  if [ -e "$TEST_HOME/.claude/commands/kaizen-suggest-next.md" ] || \
     [ -L "$TEST_HOME/.claude/commands/kaizen-suggest-next.md" ]; then
    echo "  FAIL: kaizen-suggest-next.md should be removed"
    ok=1
  fi
  if [ -e "$TEST_HOME/.claude/commands/kaizen-reflect-learning.md" ] || \
     [ -L "$TEST_HOME/.claude/commands/kaizen-reflect-learning.md" ]; then
    echo "  FAIL: kaizen-reflect-learning.md should be removed"
    ok=1
  fi

  # Output should mention removal
  if ! grep -q "Removed legacy global command" <<<"$output"; then
    echo "  FAIL: Output should mention removed legacy commands"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: Non-force warns about legacy global kaizen commands ---

test_no_force_warns_legacy_commands() {
  local test_name="Non-force setup warns about legacy commands"
  setup_test_env "$test_name"
  local ok=0

  # First: normal setup
  printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

  # Simulate legacy global command
  mkdir -p "$TEST_HOME/.claude/commands"
  ln -s "$KAIZEN_CLI_DIR/framework/.claude/commands/kaizen-suggest-next.md" \
    "$TEST_HOME/.claude/commands/kaizen-suggest-next.md"

  # Run normal setup again (not --force)
  local output
  output=$(printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" 2>&1) || true

  # Legacy command should NOT be removed
  if [ ! -L "$TEST_HOME/.claude/commands/kaizen-suggest-next.md" ]; then
    echo "  FAIL: kaizen-suggest-next.md should still exist (not --force)"
    ok=1
  fi

  # Output should warn
  if ! grep -q "Legacy global command found" <<<"$output"; then
    echo "  FAIL: Output should warn about legacy command"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== setup.sh --force flag tests ==="
echo ""

test_force_backward_compat
test_force_preserves_lang
test_force_removes_legacy_commands
test_no_force_warns_legacy_commands

print_results
