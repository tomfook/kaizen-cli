#!/bin/bash
# Tests for setup.sh shell detection, environment variables, and symlink warnings
# Usage: bash tests/test_setup_env.sh

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

# --- Test 1: zsh shell detection writes to .zshrc ---

test_zsh_shell_detection() {
  local test_name="zsh shell detection writes to .zshrc"
  setup_test_env "$test_name"
  local ok=0

  # Pipe: knowledge dir path, registry name (default), language (default en)
  printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "" | \
    HOME="$TEST_HOME" SHELL=/bin/zsh bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

  # Env vars should be in .zshrc, not .bashrc
  assert_file_exists "$TEST_HOME/.zshrc" \
    ".zshrc should be created" || ok=1
  assert_file_contains "$TEST_HOME/.zshrc" \
    "export KAIZEN_CLI_DIR=" \
    ".zshrc should contain KAIZEN_CLI_DIR" || ok=1
  assert_file_contains "$TEST_HOME/.zshrc" \
    "export KAIZEN_KNOWLEDGE_DIR=" \
    ".zshrc should contain KAIZEN_KNOWLEDGE_DIR" || ok=1

  # .bashrc should NOT have env vars (it was created empty by setup_test_env)
  if grep -q "^export KAIZEN_CLI_DIR=" "$TEST_BASHRC" 2>/dev/null; then
    echo "  FAIL: .bashrc should not contain KAIZEN_CLI_DIR when SHELL=zsh"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: --force reads env vars from previous shell's RC file ---

test_force_cross_shell_read() {
  local test_name="--force reads env vars across RC files"
  setup_test_env "$test_name"
  local ok=0

  # Simulate: env vars were previously written to .bashrc (bash user)
  echo "export KAIZEN_KNOWLEDGE_DIR=\"$TEST_KNOWLEDGE_DIR\"" >> "$TEST_BASHRC"

  # Pre-create registry so setup doesn't fail
  mkdir -p "$TEST_KNOWLEDGE_DIR/default/meta" "$TEST_KNOWLEDGE_DIR/default/projects"

  # Now run as zsh user with --force (no KAIZEN_KNOWLEDGE_DIR env var set)
  HOME="$TEST_HOME" SHELL=/bin/zsh KAIZEN_CLI_DIR="$KAIZEN_CLI_DIR" \
    bash "$KAIZEN_CLI_DIR/setup.sh" --force > /dev/null 2>&1 || true

  # Env vars should now be in .zshrc
  assert_file_exists "$TEST_HOME/.zshrc" \
    ".zshrc should be created" || ok=1
  assert_file_contains "$TEST_HOME/.zshrc" \
    "export KAIZEN_CLI_DIR=" \
    ".zshrc should contain KAIZEN_CLI_DIR" || ok=1

  # Verify KAIZEN_KNOWLEDGE_DIR value was correctly read from .bashrc
  assert_file_contains "$TEST_HOME/.zshrc" \
    "export KAIZEN_KNOWLEDGE_DIR=\"$TEST_KNOWLEDGE_DIR\"" \
    ".zshrc should contain correct KAIZEN_KNOWLEDGE_DIR value from .bashrc" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: Symlink warning present in templates and commands ---

test_symlink_warnings() {
  local test_name="Symlink warnings in templates and commands"
  setup_test_env "$test_name"
  local ok=0

  # CLAUDE.md templates should warn about Glob + symlink
  assert_file_contains "$KAIZEN_CLI_DIR/framework/templates/en/CLAUDE.md.template" \
    "Glob tool cannot follow symlinks" \
    "en/CLAUDE.md.template should contain symlink warning" || ok=1
  assert_file_contains "$KAIZEN_CLI_DIR/framework/templates/ja/CLAUDE.md.template" \
    "Glob ツールはシンボリンク先を辿れない" \
    "ja/CLAUDE.md.template should contain symlink warning" || ok=1

  # Commands that access knowledge/ should have symlink notes
  assert_file_contains "$KAIZEN_CLI_DIR/framework/.claude/commands/kaizen-update-docs.md" \
    "Glob ツールはシンボリンク先を辿れない" \
    "kaizen-update-docs.md should contain symlink warning" || ok=1
  assert_file_contains "$KAIZEN_CLI_DIR/framework/.claude/commands/kaizen-suggest-next.md" \
    "Glob ツールはシンボリンク先を辿れない" \
    "kaizen-suggest-next.md should contain symlink warning" || ok=1
  assert_file_contains "$KAIZEN_CLI_DIR/framework/.claude/commands/kaizen-reflect-learning.md" \
    "Glob ツールはシンボリンク先を辿れない" \
    "kaizen-reflect-learning.md should contain symlink warning" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== setup.sh environment & shell tests ==="
echo ""

test_zsh_shell_detection
test_force_cross_shell_read
test_symlink_warnings

print_results
