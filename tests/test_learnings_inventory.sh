#!/bin/bash
# Tests for framework/bin/kaizen-learnings-inventory.sh
# Usage: bash tests/test_learnings_inventory.sh
#
# Runs in isolated temp directories — does not affect the real environment.
# The fixtures reproduce what a search for the label gets wrong without an
# error: the example in the entry format, a sentence that mentions the word,
# the record that says a candidate was handled; and what a date-based diff gets
# wrong: a baseline that is gone, a change that was never committed.

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

INVENTORY="$KAIZEN_CLI_DIR/framework/bin/kaizen-learnings-inventory.sh"
TEMPLATES="$KAIZEN_CLI_DIR/framework/templates"

# --- Helpers ---

# run_inv <args...> — sets INV_OUT (stdout + stderr), INV_RC
run_inv() {
  INV_RC=0
  INV_OUT=$(bash "$INVENTORY" "$@" 2>&1) || INV_RC=$?
}

has() { assert_output_contains "$INV_OUT" "$1" "${2:-output should contain '$1'}"; }
hasnt() { assert_output_not_contains "$INV_OUT" "$1" "${2:-output should not contain '$1'}"; }
rc_is() {
  if [ "$INV_RC" -eq "$1" ]; then return 0; fi
  echo "  FAIL: exit code $INV_RC (want $1)"
  printf '%s\n' "$INV_OUT" | sed 's/^/    | /'
  return 1
}

# make_knowledge <dir> — a git repository with three knowledge files and a mirror
make_knowledge() {
  local k="$1"
  mkdir -p "$k/meta" "$k/aws" "$k/projects/learnings"
  echo "getting started" > "$k/meta/GETTING_STARTED.md"
  echo "guidelines" > "$k/meta/DOCUMENTATION_GUIDELINES.md"
  echo "s3" > "$k/aws/s3.md"
  echo "lambda" > "$k/aws/lambda.md"
  echo "index" > "$k/meta/INDEX.md"
  echo "mirror" > "$k/projects/learnings/demo.md"
  git -C "$k" init -q
  git -C "$k" add -A
  git -C "$k" commit -q -m "init"
}

head_of() { git -C "$1" rev-parse --short HEAD; }

# --- Test 1: no lessons file ---
test_no_file() {
  local test_name="inventory: no lessons file is not an error and not a zero"
  setup_test_env "$test_name"
  local ok=0

  run_inv --file "$TEST_HOME/docs/LEARNINGS.md" --knowledge "$TEST_HOME/none"
  rc_is 0 || ok=1
  has "status=no-file" || ok=1
  hasnt "candidates=" "a missing file must not be reported as zero candidates" || ok=1

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Test 2: the templates carry examples, not markers ---
test_templates_are_clean() {
  local test_name="inventory: the en / ja templates hold no candidate and no entry"
  setup_test_env "$test_name"
  local ok=0 lang

  for lang in en ja; do
    run_inv --file "$TEMPLATES/$lang/docs/LEARNINGS.md.template" --knowledge "$TEST_HOME/none"
    rc_is 0 || ok=1
    has "entries=0" "$lang: the entry format and the marker table are not entries" || ok=1
    has "candidates=0 (open 0, deferred 0)" "$lang: the examples must not be read as candidates" || ok=1
    has "inventories=0 (limit 3)" || ok=1
    hasnt "warning:" || ok=1
    has "status=ok" || ok=1
  done

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Test 3: what is a candidate and what is not ---
test_candidates() {
  local test_name="inventory: candidates are read by label, outside code fences, with their state"
  setup_test_env "$test_name"
  local ok=0 doc="$TEST_HOME/LEARNINGS.md"

  cat > "$doc" <<'EOF'
# Demo - Lessons

Text that mentions a Promotion candidate and 昇格候補 in a sentence.

## 棚卸しの記録

- **昇格候補**: memory deploy-notes — 他のプロジェクトでも同じ手順を踏む
- 候補 2 件は下のエントリにある（- **昇格候補**: と書く）

## Entry Format

```markdown
### [Short title] (YYYY-MM-DD)

- **Lesson**: What to do differently next time
- **Promotion candidate**: One line on why
- **昇格候補**: 理由
```

## Lessons

### S3 listing (2026-05-10)

- **Lesson**: paginate
- **Promotion candidate**: every project that lists a prefix hits this

### Token refresh (2026-06-01)

- **教訓**: 期限の前に更新する
* **昇格候補**： 認証を使う全プロジェクトに当てはまる（先送り: 同じ失敗がもう一度起きたら）

### Retry budget (2026-06-02)

- **Lesson**: cap retries
- **promotion candidate**: generic (Deferred until: a second project needs retries)

### Promoted one (2026-06-03)

- **Lesson**: done
- **Promoted**: → knowledge/aws/s3.md § Listing

### Deferred without a condition (2026-06-04)

- **Lesson**: x
- **昇格候補**: 汎用（先送り）

### Empty one (2026-06-05)

- **Lesson**: y
- **Promotion candidate**:

### Deferral with an empty condition (2026-06-06)

- **Lesson**: z
- **昇格候補**: 汎用（先送り: ）
EOF

  run_inv --file "$doc" --knowledge "$TEST_HOME/none"
  rc_is 1 || ok=1
  has "entries=7" "the heading inside the fence is not an entry" || ok=1
  has "candidates=7 (open 5, deferred 2)" || ok=1
  has "candidate: L7 [open] (§ 棚卸しの記録): - **昇格候補**: memory deploy-notes" \
    "a candidate without an entry is reported with its section" || ok=1
  has "[open] (§ S3 listing (2026-05-10)): - **Promotion candidate**: every project" || ok=1
  has "[deferred] (§ Token refresh (2026-06-01)): * **昇格候補**：" \
    "a full-width colon and a * bullet are accepted" || ok=1
  has "[deferred] (§ Retry budget (2026-06-02))" "the label is matched without regard to ASCII case" || ok=1
  has "[open] (§ Deferred without a condition (2026-06-04))" || ok=1
  has "a deferral without a condition is read as open" || ok=1
  has "[open] (§ Empty one (2026-06-05))" || ok=1
  has "[open] (§ Deferral with an empty condition (2026-06-06))" \
    "a colon with nothing after it is not a condition" || ok=1
  has "a candidate without a reason" || ok=1
  hasnt "(§ Entry Format)" "lines inside a code fence are examples" || ok=1
  hasnt "(§ Promoted one" "a promoted entry is not a candidate" || ok=1
  hasnt "候補 2 件は下の" "a line that only mentions the label is not a candidate" || ok=1
  has "note=an open candidate is not finished" || ok=1
  has "status=attention" || ok=1

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Test 4: only deferred candidates: nothing to decide ---
test_deferred_only() {
  local test_name="inventory: deferred candidates alone do not ask for a decision; one open candidate does"
  setup_test_env "$test_name"
  local ok=0 doc="$TEST_HOME/LEARNINGS.md"

  # CRLF line ends, with an example in a fence before the entry: a fence that
  # is not closed because of the CR would swallow everything after it.
  printf '%s\r\n' '# T' '' '```markdown' '- **Promotion candidate**: an example' '```' '' \
    '### One (2026-01-01)' '' \
    '- **Lesson**: x' \
    '- **Promotion candidate**: generic (deferred until: it happens in a second project)' > "$doc"

  run_inv --file "$doc" --knowledge "$TEST_HOME/none"
  rc_is 0 || ok=1
  has "entries=1" "CRLF line ends are tolerated" || ok=1
  has "candidates=1 (open 0, deferred 1)" "the fence closes on a CRLF line" || ok=1
  has "[deferred] (§ One (2026-01-01)): - **Promotion candidate**: generic" \
    "the heading is reported without the CR" || ok=1
  hasnt "note=an open candidate" || ok=1
  hasnt "warning:" || ok=1
  has "status=ok" || ok=1

  # One open candidate in the expected form: no warning, and still a decision to make.
  printf '%s\n' '# T' '' '### Two (2026-01-02)' '' '- **Lesson**: x' \
    '- **Promotion candidate**: every project that calls the API hits this' > "$doc"
  run_inv --file "$doc" --knowledge "$TEST_HOME/none"
  rc_is 1 || ok=1
  has "candidates=1 (open 1, deferred 0)" || ok=1
  hasnt "warning:" "a candidate in the expected form raises no warning" || ok=1
  has "status=attention" "an open candidate alone still asks for a decision" || ok=1

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Test 5: inventory lines ---
test_inventory_lines() {
  local test_name="inventory: the newest line gives the baseline; the form of the lines is checked"
  setup_test_env "$test_name"
  local ok=0 doc="$TEST_HOME/LEARNINGS.md" long

  cat > "$doc" <<'EOF'
# T

## Inventory Log

- **Inventory**: 2026-11-20 — graduated 0
- **Inventory**: 2026-11-27 (knowledge@abc1234) — scope: full. graduated 1 / candidates 0 / deferred 0. See 2026-01-01 for the older rule
- **棚卸し**: 2026-11-12 — 卒業 2

```markdown
- **Inventory**: 2026-12-31 (knowledge@fffffff) — an example
```
EOF

  run_inv --file "$doc" --knowledge "$TEST_HOME/none"
  rc_is 0 || ok=1
  has "inventories=3 (limit 3)" "a date in the text of a line is not a generation" || ok=1
  has "last_inventory=2026-11-27" "the newest date wins, wherever the line is" || ok=1
  has "baseline=knowledge@abc1234" || ok=1
  hasnt "fffffff" "an example inside a fence is not an inventory line" || ok=1
  hasnt "warning:" || ok=1
  has "status=ok" || ok=1

  # A fourth day, a second line for a day, a line without a date, an older line that kept its detail.
  long="$(printf 'x%.0s' $(seq 1 260))"
  cat >> "$doc" <<EOF
- **Inventory**: 2026-11-05 (knowledge@1111111) — $long
- **Inventory**: 2026-11-20 — again
- **Inventory**: soon
EOF
  run_inv --file "$doc" --knowledge "$TEST_HOME/none"
  rc_is 1 || ok=1
  has "inventories=4 (limit 3)" || ok=1
  has "warning: 4 inventory lines (limit 3)" || ok=1
  has "a second inventory line for 2026-11-20" || ok=1
  has "an inventory line without a date" || ok=1
  has "an older inventory line still carries its detail" || ok=1
  has "baseline=knowledge@abc1234" "the baseline still comes from the newest line" || ok=1
  has "status=attention" || ok=1

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Test 6: when the scope is full ---
test_scope_full() {
  local test_name="inventory: the scope is full whenever the baseline cannot be trusted"
  setup_test_env "$test_name"
  local ok=0 doc="$TEST_HOME/LEARNINGS.md" k="$TEST_HOME/k" plain="$TEST_HOME/plain" h

  make_knowledge "$k"
  h="$(head_of "$k")"
  mkdir -p "$plain/meta"; echo x > "$plain/meta/a.md"

  printf '%s\n' '# T' '' '### One (2026-01-01)' '' '- **Lesson**: x' > "$doc"

  run_inv --file "$doc" --knowledge "$TEST_HOME/none"
  has "scope=full" || ok=1
  has "scope_reason=the knowledge directory was not found" || ok=1
  has "knowledge_head=none" || ok=1
  hasnt "(knowledge@" "no commit can be recorded without a repository" || ok=1

  run_inv --file "$doc" --knowledge "$plain"
  has "scope=full" || ok=1
  has "scope_reason=the knowledge directory is not a git repository" || ok=1
  has "knowledge_head=none" || ok=1

  run_inv --file "$doc" --knowledge "$k"
  rc_is 0 || ok=1
  has "scope=full" || ok=1
  has "scope_reason=no inventory line yet" || ok=1
  has "knowledge_head=knowledge@$h" || ok=1
  has "(knowledge@$h)" "the line to write names the current commit" || ok=1
  if ! printf '%s\n' "$INV_OUT" | grep -q "^record=[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] (knowledge@$h)\$"; then
    echo "  FAIL: record= should be 'YYYY-MM-DD (knowledge@$h)'"; ok=1
  fi

  printf '%s\n' '' '- **Inventory**: 2026-11-20 — graduated 0' >> "$doc"
  run_inv --file "$doc" --knowledge "$k"
  has "scope=full" || ok=1
  has "scope_reason=the last inventory line (2026-11-20) names no knowledge@<commit>" || ok=1

  printf '%s\n' '- **Inventory**: 2026-11-21 (knowledge@0123abc) — graduated 0' >> "$doc"
  run_inv --file "$doc" --knowledge "$k"
  rc_is 0 || ok=1
  has "scope=full" || ok=1
  has "(knowledge@0123abc) is not in the knowledge repository" || ok=1
  hasnt "changed:" || ok=1

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Test 7: when the scope is narrowed ---
test_scope_narrowed() {
  local test_name="inventory: the scope is narrowed to what changed since the recorded commit"
  setup_test_env "$test_name"
  local ok=0 doc="$TEST_HOME/LEARNINGS.md" k="$TEST_HOME/k" h

  make_knowledge "$k"
  h="$(head_of "$k")"
  printf '%s\n' '# T' '' "- **Inventory**: 2026-11-20 (knowledge@$h) — graduated 0" '' \
    '### One (2026-01-01)' '' '- **Lesson**: x' > "$doc"

  # Nothing changed.
  run_inv --file "$doc" --knowledge "$k"
  rc_is 0 || ok=1
  has "scope=narrowed" || ok=1
  has "changed=0 of 5 file(s) since knowledge@$h" "projects/ is not part of the population" || ok=1
  has "knowledge/ has not changed since the last inventory" || ok=1
  hasnt "changed: " || ok=1

  # A mirror changes: still nothing.
  echo "more" >> "$k/projects/learnings/demo.md"
  git -C "$k" add -A; git -C "$k" commit -q -m "sync"
  run_inv --file "$doc" --knowledge "$k"
  has "changed=0 of 5 file(s)" "a change under projects/ is a mirror, not knowledge" || ok=1

  # One committed change and one that was never committed.
  echo "more" >> "$k/aws/s3.md"
  git -C "$k" add -A; git -C "$k" commit -q -m "s3"
  echo "wip" >> "$k/meta/INDEX.md"
  run_inv --file "$doc" --knowledge "$k"
  rc_is 0 || ok=1
  has "scope=narrowed" || ok=1
  has "changed=2 of 5 file(s) since knowledge@$h" || ok=1
  has "changed: aws/s3.md" || ok=1
  has "changed: meta/INDEX.md" "an uncommitted change counts" || ok=1
  has "knowledge_head=knowledge@$(head_of "$k")" || ok=1

  # A new file that is not tracked yet: 3 of 6 — half, so narrowing is off.
  echo "new" > "$k/aws/sqs.md"
  run_inv --file "$doc" --knowledge "$k"
  rc_is 0 || ok=1
  has "scope=full" || ok=1
  has "changed=3 of 6 file(s) since knowledge@$h" "an untracked file counts on both sides" || ok=1
  has "narrowing would leave out little" || ok=1
  hasnt "changed: " "the list is not printed when it does not narrow anything" || ok=1

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Test 8: the knowledge directory is a registry inside a repository, reached through a link ---
test_scope_registry_subdir() {
  local test_name="inventory: a registry subdirectory behind a symlink is diffed on its own"
  setup_test_env "$test_name"
  local ok=0 doc="$TEST_HOME/proj/docs/LEARNINGS.md" repo="$TEST_HOME/repo" h

  mkdir -p "$repo/default/meta" "$repo/default/projects/details" "$repo/other/meta" "$TEST_HOME/proj/docs"
  echo a > "$repo/default/meta/a.md"; echo b > "$repo/default/meta/b.md"; echo c > "$repo/default/meta/c.md"
  echo d > "$repo/default/projects/details/demo.md"
  echo o > "$repo/other/meta/o.md"
  git -C "$repo" init -q; git -C "$repo" add -A; git -C "$repo" commit -q -m init
  h="$(head_of "$repo")"
  ln -s "$repo/default" "$TEST_HOME/proj/knowledge"

  printf '%s\n' '# T' '' "- **棚卸し**: 2026-11-20 (knowledge@$h) — 卒業 0" > "$doc"
  echo more >> "$repo/default/meta/a.md"
  echo more >> "$repo/other/meta/o.md"
  git -C "$repo" add -A; git -C "$repo" commit -q -m change

  INV_RC=0
  INV_OUT=$(cd "$TEST_HOME/proj" && bash "$INVENTORY" 2>&1) || INV_RC=$?
  rc_is 0 || ok=1
  has "file=docs/LEARNINGS.md" "the defaults are docs/LEARNINGS.md and ./knowledge" || ok=1
  has "scope=narrowed" || ok=1
  has "changed=1 of 3 file(s) since knowledge@$h" "another registry in the same repository is not counted" || ok=1
  has "changed: meta/a.md" "paths are relative to the knowledge directory" || ok=1
  hasnt "other/meta/o.md" || ok=1

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Test 9: usage and unreadable input ---
test_usage_and_errors() {
  local test_name="inventory: usage errors and an unreadable file are not results"
  setup_test_env "$test_name"
  local ok=0

  run_inv --file
  rc_is 2 || ok=1
  run_inv extra
  rc_is 2 || ok=1
  has "unexpected argument: extra" || ok=1
  run_inv --help
  rc_is 0 || ok=1
  has "Usage:" || ok=1

  mkdir -p "$TEST_HOME/dir.md"
  run_inv --file "$TEST_HOME/dir.md"
  rc_is 3 || ok=1
  has "status=error" || ok=1
  hasnt "candidates=" "an unreadable file must not be reported as zero candidates" || ok=1

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Test 10: the lines the documents show are the lines the script reads ---

# documented_markers <file> — every marker line a document shows: list items
# (the examples inside code fences are written that way) and inline code spans
# that start with a list marker (the rows of the marker table).
documented_markers() {
  {
    grep -E '^[[:space:]]*- \*\*' "$1" || true
    grep -oE '`- \*\*[^`]*`' "$1" | sed 's/^`//; s/`$//' || true
  } | sed 's/YYYY-MM-DD/2026-11-27/; s/<commit>/abc1234/'
}

# expect_markers <label> <file> <candidates line> <inventories line>
expect_markers() {
  local label="$1" src="$2" want_c="$3" want_i="$4" doc="$TEST_HOME/shown.md" rc=0
  { echo "# shown"; echo; documented_markers "$src"; } > "$doc"
  run_inv --file "$doc" --knowledge "$TEST_HOME/none"
  has "$want_c" "$label: $want_c" || rc=1
  has "$want_i" "$label: $want_i" || rc=1
  hasnt "warning:" "$label: a documented marker line is not in the form the script reads" || rc=1
  if [ "$rc" -ne 0 ]; then printf '%s\n' "$INV_OUT" | sed 's/^/    | /'; fi
  return "$rc"
}

test_documented_markers() {
  local test_name="inventory: the marker lines shown in the templates and guidelines are read as documented"
  setup_test_env "$test_name"
  local ok=0 lang

  for lang in en ja; do
    # The entry format (one open candidate) and the marker table (one open, one deferred, one inventory line).
    expect_markers "$lang LEARNINGS template" "$TEMPLATES/$lang/docs/LEARNINGS.md.template" \
      "candidates=3 (open 2, deferred 1)" "inventories=1 (limit 3)" || ok=1
    # The two syntax blocks of the guidelines.
    expect_markers "$lang guidelines" "$TEMPLATES/$lang/knowledge/meta/DOCUMENTATION_GUIDELINES.md" \
      "candidates=2 (open 1, deferred 1)" "inventories=1 (limit 3)" || ok=1
  done

  teardown_test_env
  record_result "$test_name" "$ok"
}

# --- Run ---
test_no_file
test_templates_are_clean
test_candidates
test_deferred_only
test_inventory_lines
test_scope_full
test_scope_narrowed
test_scope_registry_subdir
test_usage_and_errors
test_documented_markers

print_results
