#!/bin/bash
# Tests for setup.sh template expansion and language selection
# Usage: bash tests/test_setup_template.sh

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

# --- Test 1: Template file structure parity ---

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

# --- Test 2: Template paths in setup.sh are valid ---

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

# --- Test 3: New setup with en (default) ---

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

# --- Test 4: New setup with ja ---

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

# --- Test 5: Invalid language input → error ---

test_invalid_language() {
  local test_name="Invalid language input (fr)"
  setup_test_env "$test_name"
  local ok=0

  # Pipe: knowledge dir path, registry name (default), language (fr - invalid)
  local output
  output=$(printf '%s\n' "$TEST_KNOWLEDGE_DIR" "" "fr" | \
    HOME="$TEST_HOME" SHELL=/bin/bash bash "$KAIZEN_CLI_DIR/setup.sh" 2>&1 || true)

  if grep -q "Error.*Language must be" <<<"$output"; then
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

# --- Run all tests ---

echo "=== setup.sh template & language tests ==="
echo ""

test_template_parity
test_template_paths_valid
test_new_setup_en
test_new_setup_ja
test_invalid_language

print_results
