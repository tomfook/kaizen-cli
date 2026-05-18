#!/bin/bash
# Shared test helpers for kaizen-cli tests
#
# Usage: source "$(cd "$(dirname "$0")" && pwd)/helper.sh"
#
# Provides:
#   - setup_test_env / teardown_test_env
#   - assert_file_exists / assert_file_contains / assert_file_not_exists
#   - assert_output_contains / assert_output_not_contains
#   - record_result / print_results
#   - SCRIPT_DIR, KAIZEN_CLI_DIR, PASS, FAIL, ERRORS

set -euo pipefail

# Guard: this file must be sourced, not executed directly.
# Exit 0 so that "bash tests/test_*.sh" glob expansion skips it gracefully.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
KAIZEN_CLI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
ERRORS=""

# --- Setup / Teardown ---

setup_test_env() {
  local test_name="$1"
  TEST_HOME="$(mktemp -d)"
  TEST_KNOWLEDGE_DIR="$TEST_HOME/kaizen-knowledge"
  TEST_BASHRC="$TEST_HOME/.bashrc"
  touch "$TEST_BASHRC"
  # Clear inherited KAIZEN_KNOWLEDGE_DIR so tests never pick up the developer's
  # real environment. Tests that need it pass it explicitly on the command line.
  unset KAIZEN_KNOWLEDGE_DIR
  export GIT_AUTHOR_NAME="kaizen-test"
  export GIT_AUTHOR_EMAIL="test@kaizen-cli"
  export GIT_COMMITTER_NAME="kaizen-test"
  export GIT_COMMITTER_EMAIL="test@kaizen-cli"
  echo "--- [$test_name] ---"
}

teardown_test_env() {
  rm -rf "$TEST_HOME"
}

# --- Assertions ---

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

assert_output_contains() {
  local output="$1"
  local pattern="$2"
  local msg="${3:-Output should contain '$pattern'}"
  if grep -qF "$pattern" <<<"$output"; then
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
  if grep -qF "$pattern" <<<"$output"; then
    echo "  FAIL: $msg"
    return 1
  else
    return 0
  fi
}

# --- Result tracking ---

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

print_results() {
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed ==="
  if [ "$FAIL" -gt 0 ]; then
    echo -e "Failed tests:$ERRORS"
    exit 1
  fi
}
