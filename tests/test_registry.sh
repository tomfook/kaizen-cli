#!/bin/bash
# Tests for framework/bin/kaizen-registry.sh
# Usage: bash tests/test_registry.sh
#
# Runs in isolated temp directories — does not affect the real environment.

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

REGISTRY="$KAIZEN_CLI_DIR/framework/bin/kaizen-registry.sh"

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

# --- Helpers ---

# run_reg <args...> — sets REG_OUT (stdout + stderr) and REG_RC
run_reg() {
  REG_RC=0
  REG_OUT=$(bash "$REGISTRY" "$@" 2>&1) || REG_RC=$?
}

assert_rc() {
  local expected="$1"
  if [ "$REG_RC" -ne "$expected" ]; then
    echo "  FAIL: exit code should be $expected, got $REG_RC"
    echo "$REG_OUT" | sed 's/^/    | /'
    return 1
  fi
}

has() { assert_output_contains "$REG_OUT" "$1" "${2:-output should contain '$1'}"; }
hasnt() { assert_output_not_contains "$REG_OUT" "$1" "${2:-output should not contain '$1'}"; }

assert_eq() {
  if [ "$1" != "$2" ]; then
    echo "  FAIL: ${3:-values differ}"
    echo "    expected: $2"
    echo "    actual:   $1"
    return 1
  fi
}

# rows <INDEX.md> — the data rows of the table (header and separator left out)
rows() { grep '^|' "$1" | sed '1,2d'; }

# A registry as setup.sh installs it.
make_registry() {
  local dir="$1" lang="${2:-en}"
  mkdir -p "$dir/projects" "$dir/meta"
  echo "$lang" > "$dir/.lang"
  cp "$KAIZEN_CLI_DIR/framework/templates/$lang/knowledge/projects/INDEX.md.template" "$dir/projects/INDEX.md"
}

# write_summary <file> <id> <name> <status> <created> <updated>
write_summary() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<EOF
---
project:
  id: "$2"
  name: "$3"
  status: $4          # planning | developing | released | completed | on-hold
  keywords: [alpha, beta]
  created: "$5"
  updated: "$6"
---

# $3

## Overview
EOF
}

setup_registry() {
  setup_test_env "$1"
  R="$TEST_KNOWLEDGE_DIR/default"
  P="$TEST_HOME/demo"
  make_registry "$R"
  write_summary "$P/docs/PROJECT_SUMMARY.md" demo "Demo Project" developing 2026-03-01 2026-03-02
}

# --- Test 1: register copies the two files and leaves INDEX.md alone ---

test_register_copies() {
  local test_name="register: mirrors the summary and the learnings, never touches INDEX.md"
  setup_registry "$test_name"
  local ok=0
  local index_before
  index_before="$(cat "$R/projects/INDEX.md")"

  # No LEARNINGS.md yet: the line says so.
  run_reg register "$R" "$P"
  assert_rc 0 || ok=1
  has "project_id=demo" || ok=1
  has "details=created" || ok=1
  has "learnings=not-synced" || ok=1
  has "learnings_reason=no docs/LEARNINGS.md" || ok=1
  has "status=ok" || ok=1
  cmp -s "$P/docs/PROJECT_SUMMARY.md" "$R/projects/details/demo.md" || { echo "  FAIL: details mirror differs from the source"; ok=1; }
  assert_file_not_exists "$R/projects/learnings/demo.md" || ok=1

  # A LEARNINGS.md without an entry is not mirrored.
  printf '# Learnings\n\n(none yet)\n' > "$P/docs/LEARNINGS.md"
  run_reg register "$R" "$P"
  assert_rc 0 || ok=1
  has "details=unchanged" || ok=1
  has "learnings=not-synced" || ok=1
  has "no entry yet" || ok=1
  assert_file_not_exists "$R/projects/learnings/demo.md" || ok=1

  # With an entry it is.
  printf '# Learnings\n\n### First lesson\n\n- **Lesson**: x\n' > "$P/docs/LEARNINGS.md"
  run_reg register "$R" "$P"
  assert_rc 0 || ok=1
  has "learnings=created" || ok=1
  cmp -s "$P/docs/LEARNINGS.md" "$R/projects/learnings/demo.md" || { echo "  FAIL: learnings mirror differs from the source"; ok=1; }

  # Idempotent, then follows an edit.
  run_reg register "$R" "$P"
  has "details=unchanged" || ok=1
  has "learnings=unchanged" || ok=1
  echo "more" >> "$P/docs/PROJECT_SUMMARY.md"
  run_reg register "$R" "$P"
  has "details=updated" || ok=1
  has "learnings=unchanged" || ok=1

  # Once mirrored, the mirror follows the source even when the entries are gone.
  printf '# Learnings\n\n(all promoted)\n' > "$P/docs/LEARNINGS.md"
  run_reg register "$R" "$P"
  has "learnings=updated" || ok=1
  cmp -s "$P/docs/LEARNINGS.md" "$R/projects/learnings/demo.md" || { echo "  FAIL: the mirror keeps entries the source dropped"; ok=1; }

  # The source disappeared: the mirror is kept, and it is said.
  rm "$P/docs/LEARNINGS.md"
  run_reg register "$R" "$P"
  assert_rc 0 || ok=1
  has "learnings=kept" || ok=1
  has "warning: learnings/demo.md exists but docs/LEARNINGS.md does not" || ok=1
  assert_file_exists "$R/projects/learnings/demo.md" || ok=1

  assert_eq "$(cat "$R/projects/INDEX.md")" "$index_before" "register does not write INDEX.md" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: register through the project's knowledge link, from the project root ---

test_register_through_link() {
  local test_name="register: knowledge/ link as the registry, current directory as the project"
  setup_registry "$test_name"
  local ok=0

  ln -s "$R" "$P/knowledge"
  REG_RC=0
  REG_OUT=$(cd "$P" && bash "$REGISTRY" register knowledge 2>&1) || REG_RC=$?
  assert_rc 0 || ok=1
  has "details=created" || ok=1
  assert_file_exists "$R/projects/details/demo.md" || ok=1

  REG_RC=0
  REG_OUT=$(cd "$P" && bash "$REGISTRY" sync-index knowledge 2>&1) || REG_RC=$?
  assert_rc 0 || ok=1
  has "added=1" || ok=1
  assert_eq "$(rows "$R/projects/INDEX.md")" "| demo | Demo Project | developing | alpha, beta | 2026-03-02 |" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: register stops before writing ---

test_register_guards() {
  local test_name="register: id from the frontmatter, --expect-id, registry: false, missing source"
  setup_registry "$test_name"
  local ok=0

  # --expect-id: the id is the frontmatter's; a different expectation stops everything.
  run_reg register "$R" "$P" --expect-id other-name
  assert_rc 1 || ok=1
  has "id mismatch: docs/PROJECT_SUMMARY.md says 'demo', expected 'other-name'" || ok=1
  assert_file_not_exists "$R/projects/details/demo.md" || ok=1
  assert_file_not_exists "$R/projects/details/other-name.md" "no mirror under the expected name either" || ok=1
  run_reg register "$R" "$P" --expect-id demo
  assert_rc 0 || ok=1

  # registry: false — nothing is copied; existing mirrors are pointed out.
  local Q="$TEST_HOME/private"
  write_summary "$Q/docs/PROJECT_SUMMARY.md" private "Private" planning 2026-01-01 2026-01-01
  sed 's/^  status: planning.*/&\
  registry: false/' "$Q/docs/PROJECT_SUMMARY.md" > "$Q/docs/tmp" && mv "$Q/docs/tmp" "$Q/docs/PROJECT_SUMMARY.md"
  run_reg register "$R" "$Q"
  assert_rc 0 || ok=1
  has "status=skipped" || ok=1
  has "reason=registry: false" || ok=1
  hasnt "warning:" || ok=1
  assert_file_not_exists "$R/projects/details/private.md" || ok=1
  echo "# old mirror" > "$R/projects/details/private.md"
  run_reg register "$R" "$Q"
  has "warning: mirrors of 'private' exist" || ok=1
  assert_file_contains "$R/projects/details/private.md" "# old mirror" "the existing mirror is not overwritten" || ok=1
  rm "$R/projects/details/private.md"

  # No frontmatter, no id, an id that is not a file name.
  local B="$TEST_HOME/bad"
  mkdir -p "$B/docs"
  echo "# Just a document" > "$B/docs/PROJECT_SUMMARY.md"
  run_reg register "$R" "$B"
  assert_rc 1 || ok=1
  has "has no frontmatter with a \`project:\` mapping" || ok=1
  printf -- '---\nproject:\n  name: "No Id"\n---\n' > "$B/docs/PROJECT_SUMMARY.md"
  run_reg register "$R" "$B"
  assert_rc 1 || ok=1
  has "project.id is empty" || ok=1
  printf -- '---\nproject:\n  id: "../escape"\n---\n' > "$B/docs/PROJECT_SUMMARY.md"
  run_reg register "$R" "$B"
  assert_rc 1 || ok=1
  has "cannot be used as a file name" || ok=1
  assert_file_not_exists "$R/projects/escape.md" || ok=1
  assert_eq "$(ls "$R/projects/details")" "demo.md" "no failed attempt left a file" || ok=1

  # The project file is gone but its mirror exists (found by the directory name).
  rm "$P/docs/PROJECT_SUMMARY.md"
  run_reg register "$R" "$P"
  assert_rc 1 || ok=1
  has "source_lost=projects/details/demo.md" || ok=1
  has "restore it from the mirror" || ok=1
  assert_file_exists "$R/projects/details/demo.md" "the mirror is not removed" || ok=1

  # Another details file with the same id is reported at register time.
  write_summary "$P/docs/PROJECT_SUMMARY.md" demo "Demo Project" developing 2026-03-01 2026-03-02
  cp "$P/docs/PROJECT_SUMMARY.md" "$R/projects/details/demo-old-name.md"
  run_reg register "$R" "$P"
  assert_rc 0 || ok=1
  has "warning: details/demo-old-name.md also declares id 'demo'" || ok=1

  # Usage
  run_reg register
  assert_rc 2 || ok=1
  run_reg register "$R" "$P" extra
  assert_rc 2 || ok=1
  run_reg register "$TEST_HOME/no-such-registry" "$P"
  assert_rc 1 || ok=1
  has "registry directory does not exist" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: sync-index adds, updates, removes, and sorts ---

test_sync_index_lifecycle() {
  local test_name="sync-index: add, update, remove, order by created, idempotent, text around the table kept"
  setup_registry "$test_name"
  local ok=0
  local D="$R/projects/details"
  mkdir -p "$D"
  echo "" >> "$R/projects/INDEX.md"
  echo "Trailing note that is not part of the table." >> "$R/projects/INDEX.md"
  local head_before
  head_before="$(sed -n '1,/^| ID /p' "$R/projects/INDEX.md")"

  write_summary "$D/zeta.md" zeta "Zeta" planning 2026-01-05 2026-04-01
  write_summary "$D/alpha.md" alpha "Alpha" released 2026-02-01 2026-04-02
  write_summary "$D/beta.md" beta "Beta" developing 2026-02-01 2026-04-03
  write_summary "$D/nodate-b.md" nodate-b "No Date B" planning "" 2026-04-04
  write_summary "$D/nodate-a.md" nodate-a "No Date A" planning "" 2026-04-05

  run_reg sync-index "$R"
  assert_rc 0 || ok=1
  has "index=updated" || ok=1
  has "projects=5" || ok=1
  has "added=5" || ok=1
  has "updated=0" || ok=1
  has "removed=0" || ok=1
  has "added_ids=zeta,alpha,beta,nodate-a,nodate-b" || ok=1
  # created ascending, then id; no created date goes last, by id
  assert_eq "$(rows "$R/projects/INDEX.md")" "| zeta | Zeta | planning | alpha, beta | 2026-04-01 |
| alpha | Alpha | released | alpha, beta | 2026-04-02 |
| beta | Beta | developing | alpha, beta | 2026-04-03 |
| nodate-a | No Date A | planning | alpha, beta | 2026-04-05 |
| nodate-b | No Date B | planning | alpha, beta | 2026-04-04 |" "rows and their order" || ok=1
  assert_eq "$(sed -n '1,/^| ID /p' "$R/projects/INDEX.md")" "$head_before" "text before the table is kept" || ok=1
  assert_eq "$(tail -n 1 "$R/projects/INDEX.md")" "Trailing note that is not part of the table." "text after the table is kept" || ok=1

  # Idempotent: byte-identical, and reported as unchanged
  cp "$R/projects/INDEX.md" "$TEST_HOME/index.first"
  run_reg sync-index "$R"
  assert_rc 0 || ok=1
  has "index=unchanged" || ok=1
  has "added=0" || ok=1
  cmp -s "$TEST_HOME/index.first" "$R/projects/INDEX.md" || { echo "  FAIL: second run changed INDEX.md"; ok=1; }

  # Update one, opt one out
  write_summary "$D/alpha.md" alpha "Alpha Renamed" completed 2026-02-01 2026-05-01
  sed 's/^  status: developing.*/&\
  registry: false/' "$D/beta.md" > "$D/beta.tmp" && mv "$D/beta.tmp" "$D/beta.md"
  run_reg sync-index "$R"
  assert_rc 0 || ok=1
  has "index=updated" || ok=1
  has "projects=4" || ok=1
  has "added=0" || ok=1
  has "updated=1" || ok=1
  has "removed=1" || ok=1
  has "updated_ids=alpha" || ok=1
  has "removed_ids=beta" || ok=1
  assert_eq "$(rows "$R/projects/INDEX.md" | sed -n '2p')" "| alpha | Alpha Renamed | completed | alpha, beta | 2026-05-01 |" || ok=1
  if grep -q '^| beta ' "$R/projects/INDEX.md"; then
    echo "  FAIL: registry: false must leave the table"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 5: the frontmatter forms the reader accepts ---

test_frontmatter_forms() {
  local test_name="sync-index: frontmatter forms (lists, quotes, comments, BOM, CRLF, defaults, pipes)"
  setup_registry "$test_name"
  local ok=0
  local D="$R/projects/details"
  mkdir -p "$D"

  cat > "$D/block.md" <<'EOF'
---
project:
  id: block
  name: 'It''s a "block" list'   # single quotes, doubled quote inside
  status: released # comment right after the value
  keywords:
    - one
    - "two, with a comma"
    - three   # comment
  created: 2026-01-01
  updated: 2026-01-02
other:
  id: not-this-one
---
EOF
  cat > "$D/flow.md" <<'EOF'
---
title: something before project
project:
    id: "flow"
    name: "A | B"
    keywords: [ one, "two, with a comma", 'three' ]   # flow list
    created: "2026-01-03"
    updated: "2026-01-04"
---
EOF
  cat > "$D/multi.md" <<'EOF'
---
project:
  id: multi
  keywords: [one,
    two,
    three]
  created: "2026-01-05"
---
EOF
  # BOM + CRLF, same-indent block list, empty keywords
  printf '\357\273\277---\r\nproject:\r\n  id: "crlf"\r\n  name: "With CRLF"\r\n  keywords:\r\n  - x\r\n  - y\r\n  created: "2026-01-06"\r\n  updated: "2026-01-07"\r\n---\r\n# T\r\n' > "$D/crlf.md"
  printf -- '---\nproject:\n  name: "Named After The File"\n  keywords: []              # Search keywords\n  created: "2026-01-08"\n---\n' > "$D/by-name.md"

  run_reg sync-index "$R"
  assert_rc 0 || ok=1
  hasnt "warning:" "all five files are usable" || ok=1
  assert_eq "$(rows "$R/projects/INDEX.md")" '| block | It'"'"'s a "block" list | released | one, two, with a comma, three | 2026-01-02 |
| flow | A \| B | planning | one, two, with a comma, three | 2026-01-04 |
| multi | multi | planning | one, two, three |  |
| crlf | With CRLF | planning | x, y | 2026-01-07 |
| by-name | Named After The File | planning |  |  |' "rows built from each frontmatter form" || ok=1

  # The table still reads back after a pipe was escaped: nothing changes on the next run
  run_reg sync-index "$R"
  has "index=unchanged" || ok=1
  has "updated=0" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: a registry that was maintained by hand loses nothing ---

test_migration_keeps_rows() {
  local test_name="sync-index: rows without a usable details file are carried over; --drop removes them"
  setup_registry "$test_name"
  local ok=0
  local D="$R/projects/details"
  mkdir -p "$D"
  cat > "$R/projects/INDEX.md" <<'EOF'
# Project Registry

Edited by hand for a year.

## Projects

| ID | Project Name | Status | Keywords | Updated |
|----|--------------|--------|----------|---------|
| legacy | Legacy Project | developing | R, tidyverse | 2026-02-17 |
| in-sync | In Sync | released | alpha, beta | 2026-04-02 |
| plain | Plain Details | planning | kw | 2026-01-01 |
| stale-row | Old Name | planning | old | 2026-01-01 |
| legacy | Legacy Project (pasted twice) | planning | dup | 2026-01-02 |
EOF
  write_summary "$D/in-sync.md" in-sync "In Sync" released 2026-02-01 2026-04-02
  write_summary "$D/stale-row.md" stale-row "New Name" developing 2026-03-01 2026-04-09
  echo "# Plain Details (written before frontmatter existed)" > "$D/plain.md"
  printf -- '---\ntitle: no project mapping\n---\n' > "$D/unmapped.md"

  run_reg sync-index "$R"
  assert_rc 0 || ok=1
  has "projects=4" || ok=1
  has "added=0" || ok=1
  has "updated=1" || ok=1
  has "removed=0" || ok=1
  has "kept_without_details=2" || ok=1
  has "kept: legacy (no details/legacy.md; row carried over as is" || ok=1
  has "kept: plain (details/plain.md has no usable frontmatter; row carried over as is" || ok=1
  has "warning: second row for id 'legacy' was dropped: | legacy | Legacy Project (pasted twice) | planning | dup | 2026-01-02 |" || ok=1
  has "warning: details/plain.md: no frontmatter — not used for the table" || ok=1
  has "warning: details/unmapped.md: no \`project:\` mapping in the frontmatter — not used for the table" || ok=1
  assert_eq "$(rows "$R/projects/INDEX.md")" "| in-sync | In Sync | released | alpha, beta | 2026-04-02 |
| stale-row | New Name | developing | alpha, beta | 2026-04-09 |
| legacy | Legacy Project | developing | R, tidyverse | 2026-02-17 |
| plain | Plain Details | planning | kw | 2026-01-01 |" "carried rows are byte-identical and come after the generated ones" || ok=1
  assert_file_contains "$R/projects/INDEX.md" "Edited by hand for a year." "the preamble is kept" || ok=1

  # --drop removes a carried row, and only that one
  run_reg sync-index "$R" --drop legacy
  assert_rc 0 || ok=1
  has "removed=1" || ok=1
  has "removed_ids=legacy" || ok=1
  has "kept_without_details=1" || ok=1
  if grep -q '^| legacy ' "$R/projects/INDEX.md"; then echo "  FAIL: --drop should remove the row"; ok=1; fi
  assert_file_contains "$R/projects/INDEX.md" "^| plain " "the other carried row stays" || ok=1

  # --drop cannot remove a project whose details file is still there
  run_reg sync-index "$R" --drop in-sync
  assert_rc 0 || ok=1
  has "warning: --drop in-sync ignored: details/in-sync.md still declares that id" || ok=1
  assert_file_contains "$R/projects/INDEX.md" "^| in-sync " || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: what nobody would notice otherwise ---

test_sync_index_warnings() {
  local test_name="sync-index: duplicate id, file name that differs from the id, orphan learnings, uncommitted mirrors"
  setup_registry "$test_name"
  local ok=0
  local D="$R/projects/details"
  mkdir -p "$D" "$R/projects/learnings"

  write_summary "$D/app.md" app "App" developing 2026-01-01 2026-02-01
  write_summary "$D/app-copy.md" app "App (older copy)" planning 2026-01-01 2026-01-15
  # Sorted before the right file, so "first one wins" would pick the copy
  write_summary "$D/aaa-wrong-name.md" tool "Tool Under Another Name" planning 2026-01-02 2026-02-02
  write_summary "$D/tool.md" tool "Tool" released 2026-01-02 2026-02-03
  write_summary "$D/misnamed.md" lonely "Lonely" planning 2026-01-03 2026-02-04
  echo "### lesson" > "$R/projects/learnings/app.md"
  echo "### lesson" > "$R/projects/learnings/ghost.md"

  run_reg sync-index "$R"
  assert_rc 0 || ok=1
  has "projects=3" || ok=1
  has "warning: duplicate id 'app': using details/app.md, ignoring details/app-copy.md" || ok=1
  has "warning: duplicate id 'tool': using details/tool.md, ignoring details/aaa-wrong-name.md" || ok=1
  has "warning: details/misnamed.md declares id 'lonely' — the file name differs from the id" || ok=1
  has "warning: learnings/ghost.md has no details/ghost.md" || ok=1
  hasnt "learnings/app.md has no" || ok=1
  assert_eq "$(rows "$R/projects/INDEX.md")" "| app | App | developing | alpha, beta | 2026-02-01 |
| tool | Tool | released | alpha, beta | 2026-02-03 |
| lonely | Lonely | planning | alpha, beta | 2026-02-04 |" "the file named after the id wins" || ok=1
  hasnt "uncommitted_details" "no git repository, no such line" || ok=1

  # In a git repository, mirrors that are not committed are pointed out
  git -C "$TEST_KNOWLEDGE_DIR" init -q
  git -C "$TEST_KNOWLEDGE_DIR" config commit.gpgsign false
  git -C "$TEST_KNOWLEDGE_DIR" add -A
  git -C "$TEST_KNOWLEDGE_DIR" commit -q -m init
  run_reg sync-index "$R"
  hasnt "uncommitted_details" "everything is committed" || ok=1
  echo "edited by another session" >> "$D/tool.md"
  write_summary "$D/fresh.md" fresh "Fresh" planning 2026-01-09 2026-02-09
  run_reg sync-index "$R"
  assert_rc 0 || ok=1
  has "uncommitted_details=2" || ok=1
  has "uncommitted:  M projects/details/tool.md" "paths are relative to the registry" || ok=1
  has "uncommitted: ?? projects/details/fresh.md" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 8: --dry-run, a missing INDEX.md, and tables that cannot be rebuilt ---

test_sync_index_dry_run_and_errors() {
  local test_name="sync-index: --dry-run writes nothing, missing INDEX is created, unreadable tables are refused"
  setup_registry "$test_name"
  local ok=0
  local D="$R/projects/details"
  mkdir -p "$D"
  write_summary "$D/demo.md" demo "Demo" planning 2026-01-01 2026-01-02
  cp "$R/projects/INDEX.md" "$TEST_HOME/index.before"

  run_reg sync-index "$R" --dry-run
  assert_rc 0 || ok=1
  has "index=would-be-updated" || ok=1
  has "added=1" || ok=1
  cmp -s "$TEST_HOME/index.before" "$R/projects/INDEX.md" || { echo "  FAIL: --dry-run changed INDEX.md"; ok=1; }
  assert_eq "$(ls "$R/projects" | LC_ALL=C sort)" "$(printf 'INDEX.md\ndetails')" "--dry-run leaves no temporary file" || ok=1

  # Missing INDEX.md: created from the template of the registry's language
  local J="$TEST_KNOWLEDGE_DIR/ja-reg"
  mkdir -p "$J/projects/details"
  echo "ja" > "$J/.lang"
  write_summary "$J/projects/details/demo.md" demo "デモ" planning 2026-01-01 2026-01-02
  run_reg sync-index "$J" --dry-run
  assert_rc 0 || ok=1
  has "index=would-be-created" || ok=1
  assert_file_not_exists "$J/projects/INDEX.md" || ok=1
  run_reg sync-index "$J"
  assert_rc 0 || ok=1
  has "index=created" || ok=1
  assert_file_contains "$J/projects/INDEX.md" "# プロジェクトレジストリ" "the Japanese template is used" || ok=1
  assert_eq "$(rows "$J/projects/INDEX.md")" "| demo | デモ | planning | alpha, beta | 2026-01-02 |" || ok=1

  # No table header: refused, file unchanged
  printf '# Registry\n\nThe table was deleted by accident.\n' > "$R/projects/INDEX.md"
  cp "$R/projects/INDEX.md" "$TEST_HOME/index.broken"
  run_reg sync-index "$R"
  assert_rc 1 || ok=1
  has "status=error" || ok=1
  has "error=table header not found" || ok=1
  cmp -s "$TEST_HOME/index.broken" "$R/projects/INDEX.md" || { echo "  FAIL: a refused run changed INDEX.md"; ok=1; }

  # A table with other columns: refused, file unchanged
  printf '| ID | Name | Owner |\n|----|------|-------|\n| demo | Demo | me |\n' > "$R/projects/INDEX.md"
  cp "$R/projects/INDEX.md" "$TEST_HOME/index.broken"
  run_reg sync-index "$R"
  assert_rc 1 || ok=1
  has "has 3 columns; expected 5" || ok=1
  cmp -s "$TEST_HOME/index.broken" "$R/projects/INDEX.md" || { echo "  FAIL: a refused run changed INDEX.md"; ok=1; }

  # Usage
  run_reg sync-index
  assert_rc 2 || ok=1
  run_reg sync-index "$R" --unknown
  assert_rc 2 || ok=1
  run_reg
  assert_rc 2 || ok=1
  run_reg sync-index "$TEST_HOME/no-such-registry"
  assert_rc 1 || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 9: status ---

test_status() {
  local test_name="status: clean, stale, missing, outdated INDEX, uncommitted, opted out, cannot determine"
  setup_registry "$test_name"
  local ok=0
  printf '# Learnings\n\n### First lesson\n' > "$P/docs/LEARNINGS.md"

  # Not registered yet
  run_reg status "$R" "$P"
  assert_rc 1 || ok=1
  has "details=missing" || ok=1
  has "learnings=missing" || ok=1
  has "status=drift" || ok=1
  has "fix=/kaizen-update-docs" || ok=1
  hasnt "note=" "nothing can be lost when there is no mirror yet" || ok=1

  # Mirrored, but the table does not have the row yet
  run_reg register "$R" "$P"
  run_reg status "$R" "$P"
  assert_rc 1 || ok=1
  has "details=match" || ok=1
  has "learnings=match" || ok=1
  has "index=outdated" || ok=1

  run_reg sync-index "$R"
  run_reg status "$R" "$P"
  assert_rc 0 || ok=1
  has "index=current" || ok=1
  has "uncommitted=0" || ok=1
  has "status=clean" || ok=1
  hasnt "fix=" || ok=1

  # The project file was edited after the sync
  echo "edited later" >> "$P/docs/PROJECT_SUMMARY.md"
  cp "$R/projects/details/demo.md" "$TEST_HOME/mirror.before"
  run_reg status "$R" "$P"
  assert_rc 1 || ok=1
  has "details=stale" || ok=1
  has "learnings=match" || ok=1
  has "note=before syncing, diff the project file against its mirror" || ok=1
  cmp -s "$TEST_HOME/mirror.before" "$R/projects/details/demo.md" || { echo "  FAIL: status must not write"; ok=1; }
  run_reg register "$R" "$P"

  # Synced but never committed
  git -C "$TEST_KNOWLEDGE_DIR" init -q
  git -C "$TEST_KNOWLEDGE_DIR" config commit.gpgsign false
  run_reg status "$R" "$P"
  assert_rc 1 || ok=1
  has "details=match" || ok=1
  has "uncommitted=3" || ok=1
  has "uncommitted: ?? projects/details/demo.md" || ok=1
  git -C "$TEST_KNOWLEDGE_DIR" add -A
  git -C "$TEST_KNOWLEDGE_DIR" commit -q -m sync
  run_reg status "$R" "$P"
  assert_rc 0 || ok=1
  has "status=clean" || ok=1

  # LEARNINGS without an entry and without a mirror is not drift
  local Q="$TEST_HOME/quiet"
  write_summary "$Q/docs/PROJECT_SUMMARY.md" quiet "Quiet" planning 2026-01-01 2026-01-01
  printf '# Learnings\n' > "$Q/docs/LEARNINGS.md"
  run_reg register "$R" "$Q"
  run_reg sync-index "$R"
  git -C "$TEST_KNOWLEDGE_DIR" add -A
  git -C "$TEST_KNOWLEDGE_DIR" commit -q -m quiet
  run_reg status "$R" "$Q"
  assert_rc 0 || ok=1
  has "learnings=not-synced (no entry yet)" || ok=1

  # Opted out
  sed 's/^  status: planning.*/&\
  registry: false/' "$Q/docs/PROJECT_SUMMARY.md" > "$Q/docs/tmp" && mv "$Q/docs/tmp" "$Q/docs/PROJECT_SUMMARY.md"
  run_reg status "$R" "$Q"
  assert_rc 0 || ok=1
  has "registered=no (registry: false in the frontmatter)" || ok=1
  has "warning: mirrors of 'quiet' exist" || ok=1

  # Cannot determine
  rm "$P/docs/PROJECT_SUMMARY.md"
  run_reg status "$R" "$P"
  assert_rc 3 || ok=1
  has "source_lost=projects/details/demo.md" || ok=1
  mkdir -p "$TEST_HOME/empty"
  run_reg status "$R" "$TEST_HOME/empty"
  assert_rc 3 || ok=1
  has "error=docs/PROJECT_SUMMARY.md not found" || ok=1
  run_reg status
  assert_rc 2 || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 10: the distributed templates give a usable registry ---

test_templates_round_trip() {
  local test_name="templates: a project made from the template registers and lists in en and ja"
  setup_test_env "$test_name"
  local ok=0

  local lang
  for lang in en ja; do
    local reg="$TEST_KNOWLEDGE_DIR/$lang" proj="$TEST_HOME/proj-$lang"
    make_registry "$reg" "$lang"
    mkdir -p "$proj/docs"
    sed -e 's/{{PROJECT_ID}}/tpl-'"$lang"'/' -e 's/{{PROJECT_NAME}}/Template Project/' \
        -e 's/{{PROJECT_PURPOSE}}/x/' -e 's/{{DATE}}/2026-06-01/g' \
        "$KAIZEN_CLI_DIR/framework/templates/$lang/docs/PROJECT_SUMMARY.md.template" > "$proj/docs/PROJECT_SUMMARY.md"
    run_reg register "$reg" "$proj"
    assert_rc 0 || ok=1
    has "project_id=tpl-$lang" || ok=1
    run_reg sync-index "$reg"
    assert_rc 0 || ok=1
    hasnt "warning:" || ok=1
    assert_eq "$(rows "$reg/projects/INDEX.md")" "| tpl-$lang | Template Project | planning |  | 2026-06-01 |" \
      "row from the $lang template (inline comments are not part of the values)" || ok=1
    run_reg status "$reg" "$proj"
    assert_rc 0 || ok=1
  done

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== kaizen-registry.sh tests ==="
echo ""

test_register_copies
test_register_through_link
test_register_guards
test_sync_index_lifecycle
test_frontmatter_forms
test_migration_keeps_rows
test_sync_index_warnings
test_sync_index_dry_run_and_errors
test_status
test_templates_round_trip

print_results
