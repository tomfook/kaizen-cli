#!/bin/bash
# Tests for setup.sh language selection feature
# Usage: bash tests/test_setup.sh
#
# Runs in isolated temp directories — does not affect the real environment.
# Each test creates its own HOME and KAIZEN_KNOWLEDGE_DIR.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KAIZEN_CLI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
ERRORS=""

# --- Helpers ---

setup_test_env() {
  local test_name="$1"
  TEST_HOME="$(mktemp -d)"
  TEST_KNOWLEDGE_DIR="$TEST_HOME/kaizen-knowledge"
  TEST_BASHRC="$TEST_HOME/.bashrc"
  touch "$TEST_BASHRC"
  export GIT_AUTHOR_NAME="kaizen-test"
  export GIT_AUTHOR_EMAIL="test@kaizen-cli"
  export GIT_COMMITTER_NAME="kaizen-test"
  export GIT_COMMITTER_EMAIL="test@kaizen-cli"
  echo "--- [$test_name] ---"
}

teardown_test_env() {
  rm -rf "$TEST_HOME"
}

assert_file_exists() {
  local file="$1"
  local msg="${2:-File should exist: $file}"
  if [ -f "$file" ]; then
    return 0
  else
    echo "  FAIL: $msg"
    return 1
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local msg="${3:-File $file should contain '$pattern'}"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    return 0
  else
    echo "  FAIL: $msg"
    return 1
  fi
}

assert_file_not_exists() {
  local file="$1"
  local msg="${2:-File should not exist: $file}"
  if [ ! -f "$file" ]; then
    return 0
  else
    echo "  FAIL: $msg"
    return 1
  fi
}

record_result() {
  local test_name="$1"
  local exit_code="$2"
  if [ "$exit_code" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo "  PASS"
  else
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  - $test_name"
  fi
}

# --- Test 1: New setup with en (default) ---

test_new_setup_en() {
  local test_name="New setup with en (default)"
  setup_test_env "$test_name"
  local ok=0

  # Pipe: knowledge dir path, registry name (default), language (default en)
  printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

  assert_file_exists "$TEST_KNOWLEDGE_DIR/default/.lang" \
    ".lang file should be created" || ok=1
  if [ "$ok" -eq 0 ]; then
    local lang_val
    lang_val="$(cat "$TEST_KNOWLEDGE_DIR/default/.lang")"
    if [ "$lang_val" != "en" ]; then
      echo "  FAIL: .lang should be 'en', got '$lang_val'"
      ok=1
    fi
  fi

  # Check English templates were expanded
  assert_file_exists "$TEST_KNOWLEDGE_DIR/default/meta/INDEX.md" \
    "meta/INDEX.md should exist" || ok=1
  assert_file_exists "$TEST_KNOWLEDGE_DIR/default/meta/GETTING_STARTED.md" \
    "meta/GETTING_STARTED.md should exist" || ok=1
  assert_file_exists "$TEST_KNOWLEDGE_DIR/default/meta/DOCUMENTATION_GUIDELINES.md" \
    "meta/DOCUMENTATION_GUIDELINES.md should exist" || ok=1
  assert_file_exists "$TEST_KNOWLEDGE_DIR/default/projects/INDEX.md" \
    "projects/INDEX.md should exist" || ok=1

  # Verify content is English (not Japanese)
  assert_file_contains "$TEST_KNOWLEDGE_DIR/default/meta/INDEX.md" \
    "Reverse Lookup Reference" \
    "INDEX.md should be in English" || ok=1
  assert_file_contains "$TEST_KNOWLEDGE_DIR/default/meta/GETTING_STARTED.md" \
    "Operations Guide" \
    "GETTING_STARTED.md should be in English" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: New setup with ja ---

test_new_setup_ja() {
  local test_name="New setup with ja"
  setup_test_env "$test_name"
  local ok=0

  # Pipe: knowledge dir path, registry name (default), language (ja)
  printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "ja" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

  assert_file_exists "$TEST_KNOWLEDGE_DIR/default/.lang" \
    ".lang file should be created" || ok=1
  if [ "$ok" -eq 0 ]; then
    local lang_val
    lang_val="$(cat "$TEST_KNOWLEDGE_DIR/default/.lang")"
    if [ "$lang_val" != "ja" ]; then
      echo "  FAIL: .lang should be 'ja', got '$lang_val'"
      ok=1
    fi
  fi

  # Verify content is Japanese
  assert_file_contains "$TEST_KNOWLEDGE_DIR/default/meta/INDEX.md" \
    "逆引きリファレンス" \
    "INDEX.md should be in Japanese" || ok=1
  assert_file_contains "$TEST_KNOWLEDGE_DIR/default/meta/GETTING_STARTED.md" \
    "運用ガイド" \
    "GETTING_STARTED.md should be in Japanese" || ok=1
  assert_file_contains "$TEST_KNOWLEDGE_DIR/default/meta/DOCUMENTATION_GUIDELINES.md" \
    "ドキュメントガイドライン" \
    "DOCUMENTATION_GUIDELINES.md should be in Japanese" || ok=1
  assert_file_contains "$TEST_KNOWLEDGE_DIR/default/projects/INDEX.md" \
    "プロジェクトレジストリ" \
    "projects/INDEX.md should be in Japanese" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: --force with existing registry (no .lang) → backward compatible ---

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

# --- Test 4: --force with existing .lang=ja → preserves language ---

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

# --- Test 5: Invalid language input → error ---

test_invalid_language() {
  local test_name="Invalid language input (fr)"
  setup_test_env "$test_name"
  local ok=0

  # Pipe: knowledge dir path, registry name (default), language (fr - invalid)
  local output
  output=$(printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "fr" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" 2>&1 || true)

  if echo "$output" | grep -q "Error.*Language must be"; then
    : # expected
  else
    echo "  FAIL: Should show error for invalid language 'fr'"
    ok=1
  fi

  # .lang should NOT be created
  assert_file_not_exists "$TEST_KNOWLEDGE_DIR/default/.lang" \
    ".lang should not be created on error" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: Template file structure parity ---

test_template_parity() {
  local test_name="Template en/ja file parity"
  setup_test_env "$test_name"
  local ok=0

  local en_dir="$KAIZEN_CLI_DIR/framework/templates/en"
  local ja_dir="$KAIZEN_CLI_DIR/framework/templates/ja"

  # Both directories should have the same set of files
  local en_files ja_files
  en_files=$(cd "$en_dir" && find . -type f | sort)
  ja_files=$(cd "$ja_dir" && find . -type f | sort)

  if [ "$en_files" != "$ja_files" ]; then
    echo "  FAIL: en/ and ja/ template directories have different file structures"
    echo "  en files: $en_files"
    echo "  ja files: $ja_files"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: Template paths in setup.sh are valid ---

test_template_paths_valid() {
  local test_name="Template paths in setup.sh reference valid files"
  setup_test_env "$test_name"
  local ok=0

  for lang in en ja; do
    local tdir="$KAIZEN_CLI_DIR/framework/templates/$lang"
    assert_file_exists "$tdir/knowledge/meta/INDEX.md.template" \
      "$lang/knowledge/meta/INDEX.md.template should exist" || ok=1
    assert_file_exists "$tdir/knowledge/meta/GETTING_STARTED.md" \
      "$lang/knowledge/meta/GETTING_STARTED.md should exist" || ok=1
    assert_file_exists "$tdir/knowledge/meta/DOCUMENTATION_GUIDELINES.md" \
      "$lang/knowledge/meta/DOCUMENTATION_GUIDELINES.md should exist" || ok=1
    assert_file_exists "$tdir/knowledge/projects/INDEX.md.template" \
      "$lang/knowledge/projects/INDEX.md.template should exist" || ok=1
    assert_file_exists "$tdir/CLAUDE.md.template" \
      "$lang/CLAUDE.md.template should exist" || ok=1
    assert_file_exists "$tdir/docs/PROJECT_SUMMARY.md.template" \
      "$lang/docs/PROJECT_SUMMARY.md.template should exist" || ok=1
  done

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 8: zsh shell detection writes to .zshrc ---

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

# --- Test 9: --force reads env vars from previous shell's RC file ---

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

# --- Test 10: Symlink warning present in templates and commands ---

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

# --- Test 11: New setup initializes git repo in knowledge directory ---

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
    if ! echo "$tracked" | grep -q "default/meta/INDEX.md"; then
      echo "  FAIL: default/meta/INDEX.md should be tracked"
      ok=1
    fi
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 12: --force skips existing git repo ---

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

# --- Test 13: Pre-existing user git repo is not re-initialized ---

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

echo "=== Kaizen-CLI setup.sh tests ==="
echo ""

test_template_parity
test_template_paths_valid
test_new_setup_en
test_new_setup_ja
test_force_backward_compat
test_force_preserves_lang
test_invalid_language
test_zsh_shell_detection
test_force_cross_shell_read
test_symlink_warnings
test_git_init_new_setup
test_git_init_force_skip
test_git_init_preserves_user_repo

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  echo -e "Failed tests:$ERRORS"
  exit 1
fi
