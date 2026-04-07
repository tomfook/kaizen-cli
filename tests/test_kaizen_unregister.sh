#!/bin/bash
# Tests for framework/bin/kaizen-unregister.sh
# Usage: bash tests/test_kaizen_unregister.sh
#
# Runs in isolated temp directories — does not affect the real environment.

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

KAIZEN_UNREGISTER="$KAIZEN_CLI_DIR/framework/bin/kaizen-unregister.sh"

# --- Helper: create a test registry with sample data ---

create_test_registry() {
  local reg_dir="$1"
  mkdir -p "$reg_dir/projects/details"
  cat > "$reg_dir/projects/INDEX.md" << 'HEREDOC'
# Project Registry

| ID | Project Name | Status | Keywords | Updated |
|----|--------------|--------|----------|---------|
| proj-a | Project A | developing | kw1 | 2026-01-01 |
| proj-b | Project B | planning | kw2 | 2026-02-01 |
HEREDOC
  echo "# Project A summary" > "$reg_dir/projects/details/proj-a.md"
  echo "# Project B summary" > "$reg_dir/projects/details/proj-b.md"
}

# --- Test 1: list normal case ---

test_list_ok() {
  local test_name="list: normal case returns project IDs"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  local output
  output=$(bash "$KAIZEN_UNREGISTER" list "$TEST_KNOWLEDGE_DIR") || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok" || ok=1
  assert_output_contains "$output" "[kaizen-unregister-list]" \
    "Output should have opening tag" || ok=1
  assert_output_contains "$output" "[/kaizen-unregister-list]" \
    "Output should have closing tag" || ok=1
  assert_output_contains "$output" "proj-a" \
    "projects should contain proj-a" || ok=1
  assert_output_contains "$output" "proj-b" \
    "projects should contain proj-b" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: list with header-only INDEX ---

test_list_empty() {
  local test_name="list: header-only INDEX returns empty projects"
  setup_test_env "$test_name"
  local ok=0

  mkdir -p "$TEST_KNOWLEDGE_DIR/projects"
  cat > "$TEST_KNOWLEDGE_DIR/projects/INDEX.md" << 'HEREDOC'
# Project Registry

| ID | Project Name | Status | Keywords | Updated |
|----|--------------|--------|----------|---------|
HEREDOC

  local output
  output=$(bash "$KAIZEN_UNREGISTER" list "$TEST_KNOWLEDGE_DIR") || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok" || ok=1
  assert_output_contains "$output" "projects=" \
    "projects key should exist" || ok=1
  # Ensure projects value is empty
  if echo "$output" | grep -q 'projects=.'; then
    echo "  FAIL: projects should be empty, got: $(echo "$output" | grep 'projects=')"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: list with missing INDEX.md ---

test_list_no_index() {
  local test_name="list: missing INDEX.md returns error"
  setup_test_env "$test_name"
  local ok=0

  mkdir -p "$TEST_KNOWLEDGE_DIR/projects"
  local output exit_code=0
  output=$(bash "$KAIZEN_UNREGISTER" list "$TEST_KNOWLEDGE_DIR" 2>&1) || exit_code=$?

  if [ "$exit_code" -ne 1 ]; then
    echo "  FAIL: exit code should be 1, got $exit_code"
    ok=1
  fi
  assert_output_contains "$output" "status=error" \
    "status should be error" || ok=1
  assert_output_contains "$output" "INDEX.md not found" \
    "error should mention INDEX.md not found" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: list with nonexistent directory ---

test_list_dir_missing() {
  local test_name="list: nonexistent directory returns error"
  setup_test_env "$test_name"
  local ok=0

  local output exit_code=0
  output=$(bash "$KAIZEN_UNREGISTER" list "$TEST_KNOWLEDGE_DIR/nonexistent" 2>&1) || exit_code=$?

  if [ "$exit_code" -ne 1 ]; then
    echo "  FAIL: exit code should be 1, got $exit_code"
    ok=1
  fi
  assert_output_contains "$output" "status=error" \
    "status should be error" || ok=1
  assert_output_contains "$output" "does not exist" \
    "error should mention directory does not exist" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 5: show normal case ---

test_show_ok() {
  local test_name="show: normal case returns row and details_file=exists"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  local output
  output=$(bash "$KAIZEN_UNREGISTER" show "$TEST_KNOWLEDGE_DIR" "proj-a") || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok" || ok=1
  assert_output_contains "$output" "[kaizen-unregister-show]" \
    "Output should have opening tag" || ok=1
  assert_output_contains "$output" "index_row=" \
    "Output should include index_row" || ok=1
  assert_output_contains "$output" "proj-a" \
    "index_row should contain proj-a" || ok=1
  assert_output_contains "$output" "details_file=exists" \
    "details_file should be exists" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: show with no details file ---

test_show_no_details() {
  local test_name="show: no details file returns details_file=missing"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  rm "$TEST_KNOWLEDGE_DIR/projects/details/proj-a.md"
  local output
  output=$(bash "$KAIZEN_UNREGISTER" show "$TEST_KNOWLEDGE_DIR" "proj-a") || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok" || ok=1
  assert_output_contains "$output" "details_file=missing" \
    "details_file should be missing" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: show with non-existent project ---

test_show_not_found() {
  local test_name="show: non-existent project returns error"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  local output exit_code=0
  output=$(bash "$KAIZEN_UNREGISTER" show "$TEST_KNOWLEDGE_DIR" "no-such-project" 2>&1) || exit_code=$?

  if [ "$exit_code" -ne 1 ]; then
    echo "  FAIL: exit code should be 1, got $exit_code"
    ok=1
  fi
  assert_output_contains "$output" "status=error" \
    "status should be error" || ok=1
  assert_output_contains "$output" "is not registered" \
    "error should mention not registered" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 8: show without project-id argument ---

test_show_no_id() {
  local test_name="show: no project-id argument returns exit 2"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  local exit_code=0
  bash "$KAIZEN_UNREGISTER" show "$TEST_KNOWLEDGE_DIR" 2>/dev/null || exit_code=$?

  if [ "$exit_code" -ne 2 ]; then
    echo "  FAIL: exit code should be 2, got $exit_code"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 9: execute normal case ---

test_execute_ok() {
  local test_name="execute: removes INDEX row and details file"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  local output
  output=$(bash "$KAIZEN_UNREGISTER" execute "$TEST_KNOWLEDGE_DIR" "proj-a") || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok" || ok=1
  assert_output_contains "$output" "index_removed=yes" \
    "index_removed should be yes" || ok=1
  assert_output_contains "$output" "details_removed=yes" \
    "details_removed should be yes" || ok=1

  # Verify INDEX.md no longer contains proj-a
  if grep -q "proj-a" "$TEST_KNOWLEDGE_DIR/projects/INDEX.md"; then
    echo "  FAIL: INDEX.md should not contain proj-a after execute"
    ok=1
  fi

  # Verify details file is deleted
  assert_file_not_exists "$TEST_KNOWLEDGE_DIR/projects/details/proj-a.md" \
    "details/proj-a.md should be deleted" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 10: execute with no details file ---

test_execute_no_details() {
  local test_name="execute: no details file returns details_removed=no"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  rm "$TEST_KNOWLEDGE_DIR/projects/details/proj-a.md"
  local output
  output=$(bash "$KAIZEN_UNREGISTER" execute "$TEST_KNOWLEDGE_DIR" "proj-a") || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok" || ok=1
  assert_output_contains "$output" "details_removed=no" \
    "details_removed should be no" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 11: execute with non-existent project ---

test_execute_not_found() {
  local test_name="execute: non-existent project returns error"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  local output exit_code=0
  output=$(bash "$KAIZEN_UNREGISTER" execute "$TEST_KNOWLEDGE_DIR" "no-such-project" 2>&1) || exit_code=$?

  if [ "$exit_code" -ne 1 ]; then
    echo "  FAIL: exit code should be 1, got $exit_code"
    ok=1
  fi
  assert_output_contains "$output" "status=error" \
    "status should be error" || ok=1
  assert_output_contains "$output" "is not registered" \
    "error should mention not registered" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 12: execute preserves other rows ---

test_execute_preserves_others() {
  local test_name="execute: preserves other project rows"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  bash "$KAIZEN_UNREGISTER" execute "$TEST_KNOWLEDGE_DIR" "proj-a" >/dev/null || ok=1

  # proj-b should still be in INDEX.md
  assert_file_contains "$TEST_KNOWLEDGE_DIR/projects/INDEX.md" "proj-b" \
    "INDEX.md should still contain proj-b" || ok=1

  # proj-b details file should still exist
  assert_file_exists "$TEST_KNOWLEDGE_DIR/projects/details/proj-b.md" \
    "details/proj-b.md should still exist" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 13: execute preserves header and separator ---

test_execute_preserves_header() {
  local test_name="execute: preserves header and separator rows"
  setup_test_env "$test_name"
  local ok=0

  create_test_registry "$TEST_KNOWLEDGE_DIR"
  bash "$KAIZEN_UNREGISTER" execute "$TEST_KNOWLEDGE_DIR" "proj-a" >/dev/null || ok=1

  assert_file_contains "$TEST_KNOWLEDGE_DIR/projects/INDEX.md" "| ID " \
    "INDEX.md should still contain header row" || ok=1
  assert_file_contains "$TEST_KNOWLEDGE_DIR/projects/INDEX.md" "|--" \
    "INDEX.md should still contain separator row" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 14: invalid subcommand ---

test_invalid_subcommand() {
  local test_name="invalid subcommand exits with code 2"
  setup_test_env "$test_name"
  local ok=0

  local exit_code=0
  bash "$KAIZEN_UNREGISTER" foobar 2>/dev/null || exit_code=$?

  if [ "$exit_code" -ne 2 ]; then
    echo "  FAIL: exit code should be 2, got $exit_code"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 15: no subcommand ---

test_no_subcommand() {
  local test_name="no subcommand exits with code 2"
  setup_test_env "$test_name"
  local ok=0

  local exit_code=0
  bash "$KAIZEN_UNREGISTER" 2>/dev/null || exit_code=$?

  if [ "$exit_code" -ne 2 ]; then
    echo "  FAIL: exit code should be 2, got $exit_code"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== kaizen-unregister.sh tests ==="
echo ""

test_list_ok
test_list_empty
test_list_no_index
test_list_dir_missing
test_show_ok
test_show_no_details
test_show_not_found
test_show_no_id
test_execute_ok
test_execute_no_details
test_execute_not_found
test_execute_preserves_others
test_execute_preserves_header
test_invalid_subcommand
test_no_subcommand

print_results
