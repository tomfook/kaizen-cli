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
    HOME="$TEST_HOME" bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

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
    HOME="$TEST_HOME" bash "$KAIZEN_CLI_DIR/setup.sh" > /dev/null 2>&1 || true

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

  HOME="$TEST_HOME" KAIZEN_CLI_DIR="$KAIZEN_CLI_DIR" KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" \
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

  HOME="$TEST_HOME" KAIZEN_CLI_DIR="$KAIZEN_CLI_DIR" KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" \
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
    HOME="$TEST_HOME" bash "$KAIZEN_CLI_DIR/setup.sh" 2>&1 || true)

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

# --- Run all tests ---

echo "=== Kaizen-CLI setup.sh language selection tests ==="
echo ""

test_template_parity
test_template_paths_valid
test_new_setup_en
test_new_setup_ja
test_force_backward_compat
test_force_preserves_lang
test_invalid_language

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  echo -e "Failed tests:$ERRORS"
  exit 1
fi
