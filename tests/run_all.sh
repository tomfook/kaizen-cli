#!/bin/bash
# Run all test files and aggregate results
# Usage: bash tests/run_all.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_FILES=""

for test_file in "$SCRIPT_DIR"/test_*.sh; do
  echo ""
  echo "========================================"
  echo "Running: $(basename "$test_file")"
  echo "========================================"

  exit_code=0
  output=$(bash "$test_file" 2>&1) || exit_code=$?
  echo "$output"

  # Parse the Results line from output
  results_line=$(echo "$output" | grep -oP '=== Results: \K[0-9]+ passed, [0-9]+ failed' || true)
  if [ -n "$results_line" ]; then
    pass=$(echo "$results_line" | grep -oP '^[0-9]+')
    fail=$(echo "$results_line" | grep -oP '[0-9]+(?= failed)')
    TOTAL_PASS=$((TOTAL_PASS + pass))
    TOTAL_FAIL=$((TOTAL_FAIL + fail))
  fi

  if [ "$exit_code" -ne 0 ]; then
    FAILED_FILES="$FAILED_FILES\n  - $(basename "$test_file")"
  fi
done

echo ""
echo "========================================"
echo "=== Total: $TOTAL_PASS passed, $TOTAL_FAIL failed ==="
echo "========================================"

if [ -n "$FAILED_FILES" ]; then
  echo -e "Failed files:$FAILED_FILES"
  exit 1
fi
