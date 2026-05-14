#!/bin/bash
# Tests for framework/bin/kaizen-check-knowledge.sh
# Usage: bash tests/test_kaizen_check.sh
#
# Focus: knowledge/projects/ must be excluded from inventory scans
# (those files are registry sync data, not knowledge content).
# Runs in isolated temp directories — does not affect the real environment.

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

KAIZEN_CHECK="$KAIZEN_CLI_DIR/framework/bin/kaizen-check-knowledge.sh"

# --- Helper: seed a fake knowledge dir with files inside and outside projects/ ---

create_test_knowledge() {
  local kn="$1"
  mkdir -p "$kn/meta" "$kn/projects/details" "$kn/projects/learnings"

  # A normal knowledge file with last-updated metadata. Pad with lines so it's
  # easy to spot in the inventory output.
  {
    echo "# Meta doc"
    echo ""
    for i in $(seq 1 50); do echo "filler line $i"; done
    echo ""
    echo "**Last updated**: 2026-05-14"
  } > "$kn/meta/SOME.md"

  # Registry copies that must NOT be audited as knowledge content.
  echo "# Registry detail copy of PROJECT_SUMMARY" > "$kn/projects/details/foo.md"
  echo "# Registry learnings copy of LEARNINGS" > "$kn/projects/learnings/bar.md"

  # A minimal INDEX.md with a plausible row + last-updated.
  {
    echo "# INDEX"
    echo ""
    echo "| File | Lines |"
    echo "|---|---|"
    echo "| SOME.md | ~50 |"
    echo ""
    echo "**Last updated**: 2026-05-14"
  } > "$kn/meta/INDEX.md"
}

# --- Test 1: projects/details/ files are excluded from output ---

test_projects_details_excluded() {
  local test_name="check-knowledge: projects/details/ files are excluded"
  setup_test_env "$test_name"
  local ok=0

  create_test_knowledge "$TEST_KNOWLEDGE_DIR"
  local output
  output=$(KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" bash "$KAIZEN_CHECK" 2>&1) || ok=1

  assert_output_not_contains "$output" "projects/details/foo.md" \
    "projects/details/foo.md should not appear in inventory" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: projects/learnings/ files are excluded from output ---

test_projects_learnings_excluded() {
  local test_name="check-knowledge: projects/learnings/ files are excluded"
  setup_test_env "$test_name"
  local ok=0

  create_test_knowledge "$TEST_KNOWLEDGE_DIR"
  local output
  output=$(KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" bash "$KAIZEN_CHECK" 2>&1) || ok=1

  assert_output_not_contains "$output" "projects/learnings/bar.md" \
    "projects/learnings/bar.md should not appear in inventory" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: meta/ files are still included (exclusion must not overshoot) ---

test_meta_files_included() {
  local test_name="check-knowledge: meta/ files are still included"
  setup_test_env "$test_name"
  local ok=0

  create_test_knowledge "$TEST_KNOWLEDGE_DIR"
  local output
  output=$(KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" bash "$KAIZEN_CHECK" 2>&1) || ok=1

  assert_output_contains "$output" "meta/SOME.md" \
    "meta/SOME.md should appear in inventory (exclusion should not overshoot)" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: subdir=projects/ explicit target yields empty inventory ---

test_target_subdir_projects_yields_empty_inventory() {
  local test_name="check-knowledge: subdir=projects/ explicit target excludes everything"
  setup_test_env "$test_name"
  local ok=0

  create_test_knowledge "$TEST_KNOWLEDGE_DIR"
  local output
  output=$(KAIZEN_KNOWLEDGE_DIR="$TEST_KNOWLEDGE_DIR" bash "$KAIZEN_CHECK" "projects" 2>&1) || ok=1

  # Neither registry file should appear even when projects/ is explicitly targeted —
  # the exclusion is intentional and unconditional (registry data is auto-managed).
  assert_output_not_contains "$output" "details/foo.md" \
    "details/foo.md should not appear when explicitly targeting projects/" || ok=1
  assert_output_not_contains "$output" "learnings/bar.md" \
    "learnings/bar.md should not appear when explicitly targeting projects/" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== kaizen-check-knowledge.sh tests ==="
echo ""

test_projects_details_excluded
test_projects_learnings_excluded
test_meta_files_included
test_target_subdir_projects_yields_empty_inventory

print_results
