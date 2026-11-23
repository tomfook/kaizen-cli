#!/bin/bash
# Tests for the check-links / sync-links subcommands of framework/bin/kaizen-init.sh
# Usage: bash tests/test_kaizen_init_links.sh
#
# Runs in isolated temp directories — does not affect the real environment.
# The script locates the distribution from its own path, so each test copies it
# into a fake distribution tree ($FAKE_CLI) that the test is free to mutate.

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

KAIZEN_INIT="$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh"

# --- Fixture ---

# Fake distribution: 2 skills (one of them the globally linked init skill),
# 2 commands, 1 agent => 4 items expected per project.
setup_links_env() {
  setup_test_env "$1"
  FAKE_CLI="$TEST_HOME/cli"
  FAKE_DIST="$FAKE_CLI/framework/.claude"
  FAKE_INIT="$FAKE_CLI/framework/bin/kaizen-init.sh"
  TEST_PROJECT="$TEST_HOME/project"

  mkdir -p "$FAKE_CLI/framework/bin" \
    "$FAKE_DIST/skills/kaizen-alpha" "$FAKE_DIST/skills/kaizen-init-project" \
    "$FAKE_DIST/commands" "$FAKE_DIST/agents" "$TEST_PROJECT"
  cp "$KAIZEN_INIT" "$FAKE_INIT"
  echo "alpha" > "$FAKE_DIST/skills/kaizen-alpha/SKILL.md"
  echo "init" > "$FAKE_DIST/skills/kaizen-init-project/SKILL.md"
  echo "one" > "$FAKE_DIST/commands/kaizen-one.md"
  echo "two" > "$FAKE_DIST/commands/kaizen-two.md"
  echo "agent" > "$FAKE_DIST/agents/kaizen-agent.md"
}

# run_links <subcommand> [args...] — sets LINKS_OUTPUT and LINKS_RC
run_links() {
  LINKS_RC=0
  LINKS_OUTPUT=$(bash "$FAKE_INIT" "$@" 2>&1) || LINKS_RC=$?
}

assert_rc() {
  local expected="$1"
  if [ "$LINKS_RC" -ne "$expected" ]; then
    echo "  FAIL: exit code should be $expected, got $LINKS_RC"
    echo "$LINKS_OUTPUT" | sed 's/^/    | /'
    return 1
  fi
}

# --- Test 1: fresh project reports every distributed item as missing ---

test_check_links_fresh_project() {
  local test_name="check-links: fresh project reports all items missing (exit 1)"
  setup_links_env "$test_name"
  local ok=0

  run_links check-links "$TEST_PROJECT"

  assert_rc 1 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "[kaizen-links]" "opening tag" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "[/kaizen-links]" "closing tag" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=drift" "status should be drift" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "expected=4" "4 items expected" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "missing=4" "4 items missing" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "missing: skills/kaizen-alpha" "skill listed" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "missing: commands/kaizen-one.md" "command listed" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "missing: agents/kaizen-agent.md" "agent listed" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "sync-links" "fix line should name sync-links" || ok=1
  assert_output_not_contains "$LINKS_OUTPUT" "kaizen-init-project" \
    "globally linked init skill must not be expected per project" || ok=1
  # check-links is read-only
  if [ -e "$TEST_PROJECT/.claude" ]; then
    echo "  FAIL: check-links must not create .claude/"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: sync-links creates the links, then check-links is clean ---

test_sync_links_creates_links() {
  local test_name="sync-links: creates links to the distribution, check-links then clean"
  setup_links_env "$test_name"
  local ok=0

  run_links sync-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=synced" "status should be synced" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "linked=4" "4 links created" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "linked: commands/kaizen-two.md" "created link listed" || ok=1

  local item
  for item in skills/kaizen-alpha commands/kaizen-one.md commands/kaizen-two.md agents/kaizen-agent.md; do
    if [ ! -L "$TEST_PROJECT/.claude/$item" ]; then
      echo "  FAIL: $item should be a symlink"
      ok=1
    elif [ ! "$TEST_PROJECT/.claude/$item" -ef "$FAKE_DIST/$item" ]; then
      echo "  FAIL: $item should resolve to the distributed item"
      ok=1
    fi
  done
  if [ -e "$TEST_PROJECT/.claude/skills/kaizen-init-project" ]; then
    echo "  FAIL: kaizen-init-project must not be linked per project"
    ok=1
  fi
  # Content is reachable through the link (skill directory link included)
  assert_file_contains "$TEST_PROJECT/.claude/skills/kaizen-alpha/SKILL.md" "alpha" || ok=1

  run_links check-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=clean" "status should be clean after sync" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "missing=0" "no missing items" || ok=1
  assert_output_not_contains "$LINKS_OUTPUT" "fix=" "no fix line when clean" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: sync-links is idempotent ---

test_sync_links_idempotent() {
  local test_name="sync-links: second run changes nothing (idempotent)"
  setup_links_env "$test_name"
  local ok=0

  run_links sync-links "$TEST_PROJECT"
  local before after
  before=$(cd "$TEST_PROJECT/.claude" && find . -exec ls -ld {} + | awk '{print $1, $NF}' | sort)

  run_links sync-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=unchanged" "status should be unchanged" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "linked=0" "no links created" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "removed=0" "no links removed" || ok=1

  after=$(cd "$TEST_PROJECT/.claude" && find . -exec ls -ld {} + | awk '{print $1, $NF}' | sort)
  if [ "$before" != "$after" ]; then
    echo "  FAIL: .claude/ changed on the second run"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: a command added to the distribution is reported as missing ---

test_check_links_detects_new_item() {
  local test_name="check-links: item added to the distribution after init is missing"
  setup_links_env "$test_name"
  local ok=0

  run_links sync-links "$TEST_PROJECT"
  echo "three" > "$FAKE_DIST/commands/kaizen-three.md"

  run_links check-links "$TEST_PROJECT"
  assert_rc 1 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=drift" "status should be drift" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "missing=1" "exactly one missing" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "missing: commands/kaizen-three.md" "new command listed" || ok=1

  run_links sync-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "linked=1" "only the new command is linked" || ok=1
  assert_file_contains "$TEST_PROJECT/.claude/commands/kaizen-three.md" "three" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 5: an item removed from the distribution leaves a dangling link ---

test_dangling_removed_upstream() {
  local test_name="dangling: item removed upstream is reported and unlinked by sync-links"
  setup_links_env "$test_name"
  local ok=0

  run_links sync-links "$TEST_PROJECT"
  rm "$FAKE_DIST/agents/kaizen-agent.md"
  rm -r "$FAKE_DIST/skills/kaizen-alpha"

  run_links check-links "$TEST_PROJECT"
  assert_rc 1 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "dangling=2" "two dangling links" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "dangling: agents/kaizen-agent.md -> " "agent listed with target" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "dangling: skills/kaizen-alpha -> " "skill listed with target" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "missing=0" "removed items are not missing" || ok=1

  run_links sync-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "removed=2" "two links removed" || ok=1
  if [ -L "$TEST_PROJECT/.claude/agents/kaizen-agent.md" ] || [ -L "$TEST_PROJECT/.claude/skills/kaizen-alpha" ]; then
    echo "  FAIL: dangling links should be gone after sync-links"
    ok=1
  fi

  run_links check-links "$TEST_PROJECT"
  assert_rc 0 || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: a link to a moved distribution is re-pointed ---

test_dangling_relinked_when_still_distributed() {
  local test_name="dangling: link to an old location is replaced when the item is still distributed"
  setup_links_env "$test_name"
  local ok=0

  mkdir -p "$TEST_PROJECT/.claude/commands"
  ln -s "$TEST_HOME/old-clone/framework/.claude/commands/kaizen-one.md" \
    "$TEST_PROJECT/.claude/commands/kaizen-one.md"

  run_links check-links "$TEST_PROJECT"
  assert_rc 1 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "dangling: commands/kaizen-one.md -> $TEST_HOME/old-clone" \
    "old target shown" || ok=1
  assert_output_not_contains "$LINKS_OUTPUT" "missing: commands/kaizen-one.md" \
    "a dangling item is not double-counted as missing" || ok=1

  run_links sync-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "removed: commands/kaizen-one.md" "old link removed" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "linked: commands/kaizen-one.md" "new link created" || ok=1
  assert_file_contains "$TEST_PROJECT/.claude/commands/kaizen-one.md" "one" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: user-owned entries (no kaizen- prefix) are never touched ---

test_sync_links_leaves_user_entries() {
  local test_name="sync-links: user-owned skills/commands/agents are untouched"
  setup_links_env "$test_name"
  local ok=0

  mkdir -p "$TEST_PROJECT/.claude/commands" "$TEST_PROJECT/.claude/skills/my-skill" \
    "$TEST_PROJECT/.claude/agents"
  echo "mine" > "$TEST_PROJECT/.claude/commands/my-cmd.md"
  echo "mine" > "$TEST_PROJECT/.claude/skills/my-skill/SKILL.md"
  echo "mine" > "$TEST_PROJECT/.claude/agents/my-agent.md"
  # A user's own broken symlink is not ours to clean up
  ln -s "$TEST_HOME/nowhere.md" "$TEST_PROJECT/.claude/commands/my-broken.md"

  run_links sync-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "removed=0" "nothing removed" || ok=1
  assert_output_not_contains "$LINKS_OUTPUT" "my-" "user entries are not reported" || ok=1

  assert_file_contains "$TEST_PROJECT/.claude/commands/my-cmd.md" "mine" || ok=1
  assert_file_contains "$TEST_PROJECT/.claude/skills/my-skill/SKILL.md" "mine" || ok=1
  assert_file_contains "$TEST_PROJECT/.claude/agents/my-agent.md" "mine" || ok=1
  if [ ! -L "$TEST_PROJECT/.claude/commands/my-broken.md" ]; then
    echo "  FAIL: user's own dangling symlink must be left in place"
    ok=1
  fi

  run_links check-links "$TEST_PROJECT"
  assert_rc 0 || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 8: a copy under a distributed name is foreign (listed, not drift, not modified) ---

test_foreign_copy() {
  local test_name="foreign: regular file under a distributed name is reported and kept"
  setup_links_env "$test_name"
  local ok=0

  run_links sync-links "$TEST_PROJECT"
  rm "$TEST_PROJECT/.claude/commands/kaizen-one.md"
  echo "customized" > "$TEST_PROJECT/.claude/commands/kaizen-one.md"

  # Copying an item is the documented way to customize it: listed, but not drift.
  run_links check-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=clean" "a foreign entry alone is not drift" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "foreign=1" "one foreign entry" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "foreign: commands/kaizen-one.md (not a symlink)" \
    "copy listed as not a symlink" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "note=" "note line explains foreign entries" || ok=1
  assert_output_not_contains "$LINKS_OUTPUT" "fix=" \
    "no sync-links fix when only foreign entries exist" || ok=1

  run_links sync-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=unchanged" "sync-links changes nothing" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "foreign=1" "foreign entry still reported" || ok=1
  assert_file_contains "$TEST_PROJECT/.claude/commands/kaizen-one.md" "customized" \
    "the user's copy must survive sync-links" || ok=1
  if [ -L "$TEST_PROJECT/.claude/commands/kaizen-one.md" ]; then
    echo "  FAIL: the user's copy must not be replaced by a symlink"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 9: a link to another existing location is foreign ---

test_foreign_link_elsewhere() {
  local test_name="foreign: symlink to another existing location is reported and kept"
  setup_links_env "$test_name"
  local ok=0

  mkdir -p "$TEST_HOME/other/agents" "$TEST_PROJECT/.claude/agents"
  echo "other" > "$TEST_HOME/other/agents/kaizen-agent.md"
  ln -s "$TEST_HOME/other/agents/kaizen-agent.md" "$TEST_PROJECT/.claude/agents/kaizen-agent.md"

  run_links sync-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "foreign: agents/kaizen-agent.md -> $TEST_HOME/other" \
    "foreign link listed with its target" || ok=1
  assert_file_contains "$TEST_PROJECT/.claude/agents/kaizen-agent.md" "other" \
    "foreign link must not be re-pointed" || ok=1

  run_links check-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "foreign=1" "one foreign entry" || ok=1

  # Foreign entries do not mask real drift
  echo "three" > "$FAKE_DIST/commands/kaizen-three.md"
  run_links check-links "$TEST_PROJECT"
  assert_rc 1 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=drift" "missing item is still drift" || ok=1
  assert_output_contains "$LINKS_OUTPUT" "foreign=1" "foreign entry still listed" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 10: links created by the pre-sync-links init steps count as clean ---

test_legacy_link_forms_are_clean() {
  local test_name="check-links: links made by the old init steps (trailing slash) are clean"
  setup_links_env "$test_name"
  local ok=0

  mkdir -p "$TEST_PROJECT/.claude/skills" "$TEST_PROJECT/.claude/commands" "$TEST_PROJECT/.claude/agents"
  # The old skill loop globbed "*/", so skill links carry a trailing slash.
  ln -s "$FAKE_DIST/skills/kaizen-alpha/" "$TEST_PROJECT/.claude/skills/kaizen-alpha"
  ln -s "$FAKE_DIST/commands/kaizen-one.md" "$TEST_PROJECT/.claude/commands/kaizen-one.md"
  ln -s "$FAKE_DIST/commands/kaizen-two.md" "$TEST_PROJECT/.claude/commands/kaizen-two.md"
  ln -s "$FAKE_DIST/agents/kaizen-agent.md" "$TEST_PROJECT/.claude/agents/kaizen-agent.md"

  run_links check-links "$TEST_PROJECT"
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=clean" "status should be clean" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 11: project_dir defaults to the current directory ---

test_links_default_project_dir() {
  local test_name="check-links / sync-links: project_dir defaults to \$PWD"
  setup_links_env "$test_name"
  local ok=0

  LINKS_RC=0
  LINKS_OUTPUT=$(cd "$TEST_PROJECT" && bash "$FAKE_INIT" sync-links 2>&1) || LINKS_RC=$?
  assert_rc 0 || ok=1
  if [ ! -L "$TEST_PROJECT/.claude/commands/kaizen-one.md" ]; then
    echo "  FAIL: links should be created in the current directory"
    ok=1
  fi

  LINKS_RC=0
  LINKS_OUTPUT=$(cd "$TEST_PROJECT" && bash "$FAKE_INIT" check-links 2>&1) || LINKS_RC=$?
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=clean" "status should be clean" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 12: cannot determine — missing project dir / empty distribution ---

test_links_cannot_determine() {
  local test_name="check-links / sync-links: exit 3 when the result cannot be determined"
  setup_links_env "$test_name"
  local ok=0

  local sub
  for sub in check-links sync-links; do
    run_links "$sub" "$TEST_HOME/no-such-project"
    assert_rc 3 || ok=1
    assert_output_contains "$LINKS_OUTPUT" "status=error" "$sub: status=error for missing dir" || ok=1
    assert_output_contains "$LINKS_OUTPUT" "does not exist" "$sub: error names the cause" || ok=1
  done

  # A distribution with nothing to link must not read as "clean".
  rm -r "$FAKE_DIST/skills/kaizen-alpha" "$FAKE_DIST/commands" "$FAKE_DIST/agents"
  for sub in check-links sync-links; do
    run_links "$sub" "$TEST_PROJECT"
    assert_rc 3 || ok=1
    assert_output_contains "$LINKS_OUTPUT" "status=error" "$sub: status=error for empty distribution" || ok=1
    assert_output_not_contains "$LINKS_OUTPUT" "status=clean" "$sub: must not report clean" || ok=1
  done

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 13: usage error on extra arguments ---

test_links_usage_error() {
  local test_name="check-links / sync-links: extra arguments exit 2"
  setup_links_env "$test_name"
  local ok=0

  local sub
  for sub in check-links sync-links; do
    run_links "$sub" "$TEST_PROJECT" extra
    assert_rc 2 || ok=1
  done
  if [ -e "$TEST_PROJECT/.claude" ]; then
    echo "  FAIL: a usage error must not modify the project"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 14: the real distribution syncs cleanly into an empty project ---

test_links_real_distribution() {
  local test_name="sync-links: real distribution links every skill/command/agent"
  setup_links_env "$test_name"
  local ok=0

  LINKS_RC=0
  LINKS_OUTPUT=$(bash "$KAIZEN_INIT" sync-links "$TEST_PROJECT" 2>&1) || LINKS_RC=$?
  assert_rc 0 || ok=1

  local src name
  for src in "$KAIZEN_CLI_DIR"/framework/.claude/commands/kaizen-*.md \
             "$KAIZEN_CLI_DIR"/framework/.claude/agents/kaizen-*.md; do
    name="$(basename "$(dirname "$src")")/$(basename "$src")"
    if [ ! "$TEST_PROJECT/.claude/$name" -ef "$src" ]; then
      echo "  FAIL: $name should be linked to the distribution"
      ok=1
    fi
  done
  for src in "$KAIZEN_CLI_DIR"/framework/.claude/skills/kaizen-*/; do
    name="$(basename "$src")"
    [ "$name" = "kaizen-init-project" ] && continue
    if [ ! "$TEST_PROJECT/.claude/skills/$name" -ef "$src" ]; then
      echo "  FAIL: skills/$name should be linked to the distribution"
      ok=1
    fi
  done

  LINKS_RC=0
  LINKS_OUTPUT=$(bash "$KAIZEN_INIT" check-links "$TEST_PROJECT" 2>&1) || LINKS_RC=$?
  assert_rc 0 || ok=1
  assert_output_contains "$LINKS_OUTPUT" "status=clean" "real distribution should be clean after sync" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== kaizen-init.sh check-links / sync-links tests ==="
echo ""

test_check_links_fresh_project
test_sync_links_creates_links
test_sync_links_idempotent
test_check_links_detects_new_item
test_dangling_removed_upstream
test_dangling_relinked_when_still_distributed
test_sync_links_leaves_user_entries
test_foreign_copy
test_foreign_link_elsewhere
test_legacy_link_forms_are_clean
test_links_default_project_dir
test_links_cannot_determine
test_links_usage_error
test_links_real_distribution

print_results
