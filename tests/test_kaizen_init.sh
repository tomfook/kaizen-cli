#!/bin/bash
# Tests for framework/bin/kaizen-init.sh
# Usage: bash tests/test_kaizen_init.sh
#
# Runs in isolated temp directories — does not affect the real environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KAIZEN_CLI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KAIZEN_INIT="$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh"
PASS=0
FAIL=0
ERRORS=""

# --- Helpers ---

setup_test_env() {
  local test_name="$1"
  TEST_HOME="$(mktemp -d)"
  TEST_KNOWLEDGE_DIR="$TEST_HOME/kaizen-knowledge"
  echo "--- [$test_name] ---"
}

teardown_test_env() {
  rm -rf "$TEST_HOME"
}

assert_output_contains() {
  local output="$1"
  local pattern="$2"
  local msg="${3:-Output should contain '$pattern'}"
  if echo "$output" | grep -qF "$pattern"; then
    return 0
  else
    echo "  FAIL: $msg"
    return 1
  fi
}

assert_output_not_contains() {
  local output="$1"
  local pattern="$2"
  local msg="${3:-Output should not contain '$pattern'}"
  if echo "$output" | grep -qF "$pattern"; then
    echo "  FAIL: $msg"
    return 1
  else
    return 0
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

# --- Test 1: verify normal case ---

test_verify_ok() {
  local test_name="verify: normal case (status=ok with registries)"
  setup_test_env "$test_name"
  local ok=0

  mkdir -p "$TEST_KNOWLEDGE_DIR/default"
  local output
  output=$(KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" bash "$KAIZEN_INIT" verify) || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok" || ok=1
  assert_output_contains "$output" "registries=default" \
    "registries should list 'default'" || ok=1
  assert_output_contains "$output" "[kaizen-verify]" \
    "Output should have opening tag" || ok=1
  assert_output_contains "$output" "[/kaizen-verify]" \
    "Output should have closing tag" || ok=1
  assert_output_contains "$output" "kaizen_cli_dir=" \
    "Output should include kaizen_cli_dir" || ok=1
  assert_output_contains "$output" "template_dir=" \
    "Output should include template_dir" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: verify KAIZEN_KNOWLEDGE_DIR unset ---

test_verify_knowledge_dir_unset() {
  local test_name="verify: KAIZEN_KNOWLEDGE_DIR not set"
  setup_test_env "$test_name"
  local ok=0

  local output exit_code=0
  output=$(unset KAIZEN_KNOWLEDGE_DIR; bash "$KAIZEN_INIT" verify 2>&1) || exit_code=$?

  if [ "$exit_code" -ne 1 ]; then
    echo "  FAIL: exit code should be 1, got $exit_code"
    ok=1
  fi
  assert_output_contains "$output" "status=error" \
    "status should be error" || ok=1
  assert_output_contains "$output" "KAIZEN_KNOWLEDGE_DIR is not set" \
    "error message should mention unset var" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: verify KAIZEN_KNOWLEDGE_DIR directory missing ---

test_verify_knowledge_dir_missing() {
  local test_name="verify: KAIZEN_KNOWLEDGE_DIR directory does not exist"
  setup_test_env "$test_name"
  local ok=0

  local output exit_code=0
  output=$(KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR/nonexistent" bash "$KAIZEN_INIT" verify 2>&1) || exit_code=$?

  if [ "$exit_code" -ne 1 ]; then
    echo "  FAIL: exit code should be 1, got $exit_code"
    ok=1
  fi
  assert_output_contains "$output" "status=error" \
    "status should be error" || ok=1
  assert_output_contains "$output" "directory does not exist" \
    "error should mention directory does not exist" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: verify with 0 registries ---

test_verify_no_registries() {
  local test_name="verify: 0 registries (empty knowledge dir)"
  setup_test_env "$test_name"
  local ok=0

  mkdir -p "$TEST_KNOWLEDGE_DIR"
  local output
  output=$(KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" bash "$KAIZEN_INIT" verify) || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok even with 0 registries" || ok=1
  assert_output_contains "$output" "registries=" \
    "registries key should exist" || ok=1
  # Ensure registries value is empty (no names after =)
  if echo "$output" | grep -q 'registries=.'; then
    echo "  FAIL: registries should be empty, got: $(echo "$output" | grep 'registries=')"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 5: verify with multiple registries ---

test_verify_multiple_registries() {
  local test_name="verify: multiple registries"
  setup_test_env "$test_name"
  local ok=0

  mkdir -p "$TEST_KNOWLEDGE_DIR/default" "$TEST_KNOWLEDGE_DIR/work"
  local output
  output=$(KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" bash "$KAIZEN_INIT" verify) || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok" || ok=1
  # Check both registries are listed (order may vary)
  local reg_line
  reg_line=$(echo "$output" | grep '^registries=')
  if ! echo "$reg_line" | grep -q "default"; then
    echo "  FAIL: registries should include 'default'"
    ok=1
  fi
  if ! echo "$reg_line" | grep -q "work"; then
    echo "  FAIL: registries should include 'work'"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: root directory does not leak into registries (Issue #26 regression) ---

test_verify_no_root_dir_leak() {
  local test_name="verify: root directory not in registries (Issue #26)"
  setup_test_env "$test_name"
  local ok=0

  mkdir -p "$TEST_KNOWLEDGE_DIR/default"
  # Place a regular file in knowledge dir (should not appear as registry)
  touch "$TEST_KNOWLEDGE_DIR/somefile.txt"

  local output
  output=$(KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" bash "$KAIZEN_INIT" verify) || ok=1

  assert_output_contains "$output" "status=ok" \
    "status should be ok" || ok=1
  # registries should only contain 'default', not the knowledge dir itself or files
  local reg_line
  reg_line=$(echo "$output" | grep '^registries=')
  if [ "$reg_line" != "registries=default" ]; then
    echo "  FAIL: registries should be exactly 'default', got: $reg_line"
    ok=1
  fi
  # Ensure knowledge dir basename does not appear in registries
  local kdir_basename
  kdir_basename=$(basename "$TEST_KNOWLEDGE_DIR")
  assert_output_not_contains "$reg_line" "$kdir_basename" \
    "Root knowledge dir name should not appear in registries" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: invalid subcommand ---

test_invalid_subcommand() {
  local test_name="invalid subcommand exits with code 2"
  setup_test_env "$test_name"
  local ok=0

  local exit_code=0
  bash "$KAIZEN_INIT" foobar 2>/dev/null || exit_code=$?

  if [ "$exit_code" -ne 2 ]; then
    echo "  FAIL: exit code should be 2, got $exit_code"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== kaizen-init.sh tests ==="
echo ""

test_verify_ok
test_verify_knowledge_dir_unset
test_verify_knowledge_dir_missing
test_verify_no_registries
test_verify_multiple_registries
test_verify_no_root_dir_leak
test_invalid_subcommand

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  echo -e "Failed tests:$ERRORS"
  exit 1
fi
