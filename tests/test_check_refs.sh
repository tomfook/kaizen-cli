#!/bin/bash
# Tests for framework/bin/kaizen-check-refs.py
# Usage: bash tests/test_check_refs.sh
#
# Runs in isolated temp directories — does not affect the real environment.
# python3 is an optional dependency of the framework: without it the tests
# are skipped (the callers of the script skip the check in the same way).

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

CHECK_REFS="$KAIZEN_CLI_DIR/framework/bin/kaizen-check-refs.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "=== kaizen-check-refs.py tests ==="
  echo "(skipped: python3 not available)"
  print_results
  exit 0
fi

# --- Helpers ---

# run_refs <args...> — sets REFS_OUT (stdout + stderr) and REFS_RC
run_refs() {
  REFS_RC=0
  REFS_OUT=$(python3 "$CHECK_REFS" "$@" 2>&1) || REFS_RC=$?
}

assert_rc() {
  local expected="$1"
  if [ "$REFS_RC" -ne "$expected" ]; then
    echo "  FAIL: exit code should be $expected, got $REFS_RC"
    echo "$REFS_OUT" | sed 's/^/    | /'
    return 1
  fi
}

has() { assert_output_contains "$REFS_OUT" "$1" "${2:-output should contain '$1'}"; }
hasnt() { assert_output_not_contains "$REFS_OUT" "$1" "${2:-output should not contain '$1'}"; }

# A project with docs/, CLAUDE.md, and a knowledge directory inside it.
# knowledge/ holds a registry copy under projects/ that must never be indexed.
setup_project() {
  setup_test_env "$1"
  P="$TEST_HOME/project"
  K="$P/knowledge"
  mkdir -p "$P/docs" "$K/meta" "$K/aws" "$K/projects/details"
  cat > "$K/meta/GUIDE.md" <<'EOF'
# Guide

## Design Decisions（設計判断）

### Use `TMPDIR` carefully

## 3. Setup steps

## Moved section

→ `aws/S3.md § Prefix listing semantics` へ移設

## Repeated

## Repeated

- **Paging**: bold bullet that works as a heading for § references
EOF
  cat > "$K/aws/S3.md" <<'EOF'
# S3

## Prefix listing semantics

## 設定方法
EOF
  printf '# Registry copy\n\n## Overview\n' > "$K/projects/details/S3.md"
  printf '# Project\n\n## Notes\n' > "$P/CLAUDE.md"
  printf '# Summary\n\n## Overview\n\n## Design Decisions\n' > "$P/docs/PROJECT_SUMMARY.md"
}

# --- Test 1: the legacy Check 6 regression script still passes ---

test_legacy_check6_script() {
  local test_name="check-refs: legacy Check 6 regression script passes through kaizen-check-knowledge.sh"
  setup_test_env "$test_name"
  local ok=0

  local out rc=0
  out=$(bash "$KAIZEN_CLI_DIR/framework/bin/test-kaizen-check-knowledge.sh" 2>&1) || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  FAIL: test-kaizen-check-knowledge.sh exited $rc"
    echo "$out" | grep -v '^PASS' | sed 's/^/    | /'
    ok=1
  fi
  assert_output_contains "$out" "failed: 0" "no failed assertion" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: --corpus resolves path-prefixed references ---

test_corpus_path_prefixed() {
  local test_name="check-refs --corpus: path-prefixed refs, out-of-tree paths skipped, projects/ not scanned"
  setup_project "$test_name"
  local ok=0

  cat > "$K/meta/SRC.md" <<'EOF'
# Src

- ok by suffix: `aws/S3.md § 設定方法`
- ok with knowledge/ prefix: `knowledge/aws/S3.md § Prefix listing semantics`
- ok relative: `../aws/S3.md § 設定方法`
- ok bare name (projects/ copy of S3.md is not a candidate): `S3.md § 設定方法`
- broken heading under a path: `aws/S3.md § Gone heading`
- broken file inside the tree: `aws/NOPE.md § Whatever`
- project path, cannot be judged here: `docs/PROJECT_SUMMARY.md § Not Checked`
- framework path, cannot be judged here: `.claude/skills/x/SKILL.md § Not Checked Either`
- repeated heading anchor: [r](./GUIDE.md#repeated-1)
- one repetition too many: [r](./GUIDE.md#repeated-2)
> quoted line is not a reference: `aws/S3.md § Quoted Gone`
EOF
  printf '# P\n\n- `aws/S3.md § Broken In Registry Copy`\n' > "$K/projects/details/p.md"

  run_refs --corpus "$K"
  assert_rc 0 || ok=1
  hasnt "設定方法" "valid refs must not be flagged" || ok=1
  hasnt "Prefix listing semantics" "knowledge/ prefix resolves" || ok=1
  has '`aws/S3.md § Gone heading` (no matching heading)' || ok=1
  has '`aws/NOPE.md § Whatever` (referenced file not found)' || ok=1
  hasnt "Not Checked" "paths outside the knowledge tree are skipped" || ok=1
  hasnt "repeated-1" "-1 suffix of a repeated heading is valid" || ok=1
  has "GUIDE.md#repeated-2" "there is no third 'Repeated' heading" || ok=1
  hasnt "Quoted Gone" "quote lines are not checked in corpus mode" || ok=1
  hasnt "Broken In Registry Copy" "projects/ is never scanned" || ok=1

  # Scanning a subdirectory still resolves targets in sibling directories
  run_refs --corpus "$K" "$K/meta"
  assert_rc 0 || ok=1
  hasnt "設定方法" "sibling-directory target resolves in a subdirectory scan" || ok=1
  has "Gone heading" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: --corpus prints "none" when clean, tracks fences like CommonMark ---

test_corpus_clean_and_fences() {
  local test_name="check-refs --corpus: clean tree prints none; a fence after a list marker hides nothing"
  setup_project "$test_name"
  local ok=0

  cat > "$K/meta/FENCED.md" <<'EOF'
# Fenced

- ```bash
  # a comment, not a heading
  ```

## After The List Fence

```
`aws/S3.md § Ignored In Fence`
```
EOF
  printf '# Src\n\n- `FENCED.md § After The List Fence`\n- [a](./FENCED.md#after-the-list-fence)\n' > "$K/meta/SRC.md"

  run_refs --corpus "$K"
  assert_rc 0 || ok=1
  if [ "$REFS_OUT" != "none" ]; then
    echo "  FAIL: clean tree should print exactly 'none'"
    echo "$REFS_OUT" | sed 's/^/    | /'
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: --corpus argument and read errors ---

test_corpus_errors() {
  local test_name="check-refs --corpus: unreadable file is exit 2, bad arguments are exit 3"
  setup_project "$test_name"
  local ok=0

  printf '# Bad\n\n\xff\xfe not utf-8\n' > "$K/meta/BAD.md"
  printf '# Src\n\n- `BAD.md § Bad`\n- `aws/S3.md § Gone`\n' > "$K/meta/SRC.md"
  run_refs --corpus "$K"
  assert_rc 2 || ok=1
  has "Unreadable files" || ok=1
  has "meta/BAD.md (UnicodeDecodeError)" || ok=1
  has "aws/S3.md § Gone" "findings are still reported next to the unreadable file" || ok=1
  hasnt '`BAD.md § Bad` (no matching heading)' "an unreadable target is not a broken reference" || ok=1
  rm "$K/meta/BAD.md"

  run_refs --corpus "$TEST_HOME/nope"
  assert_rc 3 || ok=1
  run_refs --corpus "$K" "$K/nope"
  assert_rc 3 || ok=1
  run_refs --corpus "$K" "$P/docs"
  assert_rc 3 || ok=1
  has "outside the knowledge directory" || ok=1
  run_refs --corpus
  assert_rc 3 || ok=1
  run_refs --bogus
  assert_rc 3 || ok=1
  run_refs
  assert_rc 3 || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 5: --project classifies references ---

test_project_classification() {
  local test_name="check-refs --project: OK / OK~ / NUM / MISS, exit 1, totals on the last line"
  setup_project "$test_name"
  local ok=0

  cat > "$P/docs/NOTES.md" <<'EOF'
# Notes

- ok: `knowledge/meta/GUIDE.md § Design Decisions（設計判断）`
- ok bullet: `GUIDE.md § Paging`
- ok project doc: `docs/PROJECT_SUMMARY.md § Overview`
- ok root file: `CLAUDE.md § Notes`
- ok relative: `./PROJECT_SUMMARY.md § Overview`
- one character too many: `GUIDE.md § Design Decisions（設計判断）x`
- spelled differently: `GUIDE.md § 3.Setup steps`
- number only: `GUIDE.md § 3`
- cut short: `GUIDE.md § Design Decisions`
- no such file: `knowledge/meta/GONE.md § Anything`
- ambiguous name: `S3.md § 設定方法`
- nested backticks: `GUIDE.md § Use `TMPDIR` carefully`
- written without the inner backticks: `GUIDE.md § Use TMPDIR carefully`
> quoted lines are checked in project mode: `GUIDE.md § Quoted Gone`
EOF
  # A second S3.md in docs/ makes the bare name ambiguous (projects/ copy is not counted)
  printf '# Local S3 notes\n\n## 設定方法\n' > "$P/docs/S3.md"

  run_refs --project "$P"
  assert_rc 1 || ok=1
  hasnt "OK   docs/NOTES.md" "plain OK lines are not printed" || ok=1
  has 'OK~  docs/NOTES.md:9  `GUIDE.md § 3.Setup steps` (differs from the heading in spaces or symbols)' || ok=1
  has 'NUM  docs/NOTES.md:10  `GUIDE.md § 3` (number-only reference: write the whole heading → "3. Setup steps"; knowledge/meta/GUIDE.md)' || ok=1
  has 'MISS docs/NOTES.md:11  `GUIDE.md § Design Decisions` (no matching heading in knowledge/meta/GUIDE.md; similar: "Design Decisions（設計判断）")' \
    "an English stem alone does not match the bilingual heading; the whole heading is offered" || ok=1
  has 'MISS docs/NOTES.md:12  `knowledge/meta/GONE.md § Anything` (referenced file not found)' || ok=1
  has 'MISS docs/NOTES.md:13  `S3.md § 設定方法` (several files named S3.md: docs/S3.md, knowledge/aws/S3.md — write the path)' || ok=1
  hasnt "projects/details/S3.md" "the registry copy is not a candidate" || ok=1
  has 'docs/NOTES.md:14' "nested backticks cut the reference short" || ok=1
  has 'drop its backticks inside the reference: "Use TMPDIR carefully"' || ok=1
  hasnt "docs/NOTES.md:15" "reference without the inner backticks is OK" || ok=1
  has "MISS docs/NOTES.md:16" "quote lines are checked" || ok=1
  has 'MISS docs/NOTES.md:8  `GUIDE.md § Design Decisions（設計判断）x` (no matching heading in knowledge/meta/GUIDE.md)' \
    "neither a prefix nor a superstring of a heading matches" || ok=1
  has "total: scanned 4 file(s) / references OK 6 / OK~ 1 / MISS 7 (NUM 1) (14 of 14 extracted accounted for)" || ok=1
  if [ "$(printf '%s\n' "$REFS_OUT" | tail -1 | cut -c1-6)" != "total:" ]; then
    echo "  FAIL: the totals should be the last line"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: clean project, and a project with nothing to scan ---

test_project_clean_and_empty() {
  local test_name="check-refs --project: clean is exit 0 with the scanned count; no target is exit 3"
  setup_project "$test_name"
  local ok=0

  printf '# Notes\n\n- `knowledge/aws/S3.md § 設定方法`\n' > "$P/docs/NOTES.md"
  run_refs --project "$P"
  assert_rc 0 || ok=1
  has "total: scanned 3 file(s) / references OK 1 / OK~ 0 / MISS 0 (1 of 1 extracted accounted for)" || ok=1

  mkdir -p "$TEST_HOME/empty"
  run_refs --project "$TEST_HOME/empty"
  assert_rc 3 || ok=1
  has "no .md file to scan" "nothing to scan must not look like a pass" || ok=1
  run_refs --project "$TEST_HOME/nope"
  assert_rc 3 || ok=1
  run_refs --project "$P" docs/NOPE.md
  assert_rc 3 || ok=1
  has "path does not exist" || ok=1
  run_refs --project "$P" --bogus
  assert_rc 3 || ok=1
  run_refs --project "$P" --knowledge
  assert_rc 3 || ok=1
  run_refs --project
  assert_rc 3 || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: pointer lines (promotion markers) ---

test_project_pointer_lines() {
  local test_name="check-refs --project: '→ path § Heading' pointer lines (promotion markers, en/ja)"
  setup_project "$test_name"
  local ok=0

  cat > "$P/docs/LEARNINGS.md" <<'EOF'
# Learnings

### Entry one (2026-05-10)

- **教訓**: page with the continuation token
- **昇格先**: → knowledge/aws/S3.md § Prefix listing semantics

### Entry two

- **Promoted**: → knowledge/aws/S3.md § Renamed away
- **Promoted**: → knowledge/aws/S3.md § 設定方法  <!-- optional -->

### Entry three

→ knowledge/aws/S3.md § 設定方法 に記載済み

### Entry four

→ knowledge/aws/S3.md § 設定方法 and then more prose

The syntax is `- **昇格先**: → knowledge/<path>.md § <セクション名>` (an example, not a reference).
A placeholder in backticks is not a reference either: `→ knowledge/XXX.md § ...`
EOF

  run_refs --project "$P"
  assert_rc 1 || ok=1
  hasnt "docs/LEARNINGS.md:6" "ja marker resolves" || ok=1
  has "MISS docs/LEARNINGS.md:10  → knowledge/aws/S3.md § Renamed away (no matching heading in knowledge/aws/S3.md)" || ok=1
  hasnt "docs/LEARNINGS.md:11" "trailing HTML comment is not part of the heading" || ok=1
  hasnt "docs/LEARNINGS.md:15" "trailing 'に記載済み' is not part of the heading" || ok=1
  has 'MISS docs/LEARNINGS.md:19' "prose after an undelimited heading is a MISS" || ok=1
  has 'text follows the heading "設定方法" — put the reference in backticks to delimit it' || ok=1
  hasnt "docs/LEARNINGS.md:21" "placeholder syntax in inline code is not extracted" || ok=1
  hasnt "docs/LEARNINGS.md:22" || ok=1
  has "references OK 3 / OK~ 0 / MISS 2 (5 of 5 extracted accounted for)" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 8: where the knowledge directory comes from ---

test_project_knowledge_dir() {
  local test_name="check-refs --project: knowledge dir from --knowledge, the environment, or a symlink"
  setup_project "$test_name"
  local ok=0

  # Move knowledge out of the project: nothing points to it any more
  mv "$K" "$TEST_HOME/shared"
  printf '# Notes\n\n- `knowledge/aws/S3.md § 設定方法`\n- `meta/GUIDE.md § Paging`\n' > "$P/docs/NOTES.md"

  run_refs --project "$P"
  assert_rc 1 || ok=1
  has "knowledge directory: (none" "the missing knowledge directory is stated" || ok=1
  has "referenced file not found" || ok=1

  run_refs --project "$P" --knowledge "$TEST_HOME/shared"
  assert_rc 0 || ok=1
  has "references OK 2" || ok=1

  REFS_RC=0
  REFS_OUT=$(KAIZEN_KNOWLEDGE_DIR="$TEST_HOME/shared" python3 "$CHECK_REFS" --project "$P" 2>&1) || REFS_RC=$?
  assert_rc 0 || ok=1
  has "references OK 2" "the environment variable is used" || ok=1

  ln -s "$TEST_HOME/shared" "$P/knowledge"
  run_refs --project "$P"
  assert_rc 0 || ok=1
  has "references OK 2" "the knowledge symlink is followed" || ok=1

  run_refs --project "$P" --knowledge "$TEST_HOME/nope"
  assert_rc 3 || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 9: link anchors ---

test_project_anchors() {
  local test_name="check-refs --project: same-file and cross-file link anchors"
  setup_project "$test_name"
  local ok=0

  cat > "$P/docs/NOTES.md" <<'EOF'
# Notes

## 知識の3つの層

## Twice

## Twice

- **Bullet label**: not an anchor on a rendered page

- ok same file: [a](#知識の3つの層)
- ok repeated: [b](#twice-1)
- broken same file: [c](#l11)
- bullets have no anchor: [d](#bullet-label)
- ok cross file, the § line is covered by its anchor: [PROJECT_SUMMARY.md § Design Decisions](./PROJECT_SUMMARY.md#design-decisions)
- ok without ./: [e](PROJECT_SUMMARY.md#overview)
- broken cross file: [f](./PROJECT_SUMMARY.md#renamed)
- missing file: [g](./NOPE.md#x)
- not ours: [h](https://example.com/x.md#y)
- example in inline code: `[i](#not-checked)`
EOF

  run_refs --project "$P"
  assert_rc 1 || ok=1
  has 'MISS docs/NOTES.md:13  `#l11` (no matching heading in docs/NOTES.md)' || ok=1
  has 'MISS docs/NOTES.md:14  `#bullet-label`' || ok=1
  has 'MISS docs/NOTES.md:17  `./PROJECT_SUMMARY.md#renamed` (no matching heading in docs/PROJECT_SUMMARY.md)' || ok=1
  has 'MISS docs/NOTES.md:18  `./NOPE.md#x` (link target not found)' || ok=1
  hasnt "example.com" || ok=1
  hasnt "not-checked" || ok=1
  has "anchors: OK 4 / MISS 4" || ok=1
  has "§ lines not extracted 0" "a § line with an anchored link is not counted as unextracted" || ok=1
  has "/ anchors OK 4 / MISS 4" "anchor result is on the last line too" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 10: --list ---

test_project_list() {
  local test_name="check-refs --project --list: REF / SKIP / ANCH, nothing judged"
  setup_project "$test_name"
  local ok=0

  cat > "$P/docs/NOTES.md" <<'EOF'
# Notes

- `knowledge/meta/GONE.md § Would Be A Miss`
- → knowledge/aws/S3.md § 設定方法
- no file name: see § Overview above
- two spans: `knowledge/aws/S3.md` § 設定方法
- [a](#notes)

```markdown
> Details: `knowledge/path/FILE.md § Section`
```
EOF

  run_refs --project "$P" --list
  assert_rc 0 || ok=1
  has 'REF  docs/NOTES.md:3  `knowledge/meta/GONE.md § Would Be A Miss`' || ok=1
  has 'REF  docs/NOTES.md:4  → knowledge/aws/S3.md § 設定方法' || ok=1
  has 'SKIP docs/NOTES.md:5  - no file name: see § Overview above' || ok=1
  has 'SKIP docs/NOTES.md:6  - two spans:' || ok=1
  has 'SKIP docs/NOTES.md:10  [in code fence]' || ok=1
  has 'ANCH docs/NOTES.md:7  `#notes`' || ok=1
  has "§ lines not extracted 2 (no file name 1 / other 1)" || ok=1
  hasnt "MISS" "--list does not judge" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 11: --staged ---

test_project_staged() {
  local test_name="check-refs --project --staged: only added lines, scope stated, nothing staged is said so"
  setup_project "$test_name"
  local ok=0

  printf '# Notes\n\n- old broken line: `GUIDE.md § Old Broken`\n' > "$P/docs/NOTES.md"
  printf '# Out of scope\n' > "$P/README.md"
  git -C "$P" -c init.defaultBranch=main init -q
  git -C "$P" add -A
  git -C "$P" commit -q -m init

  run_refs --project "$P" --staged
  assert_rc 0 || ok=1
  has "nothing was checked — no staged .md in scope (staged .md 0 / checked 0)" || ok=1

  # The full scan sees the old broken line; the staged scan must not
  run_refs --project "$P"
  assert_rc 1 || ok=1

  printf -- '- new good line: `GUIDE.md § Paging`\n' >> "$P/docs/NOTES.md"
  printf 'more\n' >> "$P/README.md"
  git -C "$P" add -A
  run_refs --project "$P" --staged
  assert_rc 0 || ok=1
  has "(staged .md 1 / checked 1 / out of scope 1)" || ok=1
  hasnt "Old Broken" "a line that was not touched is not judged" || ok=1
  has "total: scanned 1 file(s) / references OK 1 / OK~ 0 / MISS 0" || ok=1

  printf -- '- new broken line: `GUIDE.md § New Broken`\n' >> "$P/docs/NOTES.md"
  run_refs --project "$P" --staged
  assert_rc 0 "unstaged edits are not part of the gate" || ok=1
  git -C "$P" add -A
  run_refs --project "$P" --staged
  assert_rc 1 || ok=1
  has 'MISS docs/NOTES.md:5  `GUIDE.md § New Broken`' || ok=1
  hasnt "Old Broken" || ok=1
  git -C "$P" commit -q -m second

  # Rename with an edit, into a name that contains a space
  git -C "$P" mv docs/NOTES.md "docs/MY NOTES.md"
  printf -- '- added after the rename: `GUIDE.md § Renamed Broken`\n' >> "$P/docs/MY NOTES.md"
  git -C "$P" add -A
  run_refs --project "$P" --staged
  assert_rc 1 || ok=1
  has 'MISS docs/MY NOTES.md:6  `GUIDE.md § Renamed Broken`' "added line of a renamed file is judged" || ok=1
  hasnt "New Broken" "lines carried over by the rename are not judged" || ok=1

  # Not a git repository
  mkdir -p "$TEST_HOME/nogit/docs"
  printf '# D\n' > "$TEST_HOME/nogit/docs/D.md"
  REFS_RC=0
  REFS_OUT=$(GIT_CEILING_DIRECTORIES="$TEST_HOME" python3 "$CHECK_REFS" --project "$TEST_HOME/nogit" --staged 2>&1) || REFS_RC=$?
  assert_rc 3 || ok=1
  has "--staged needs a git repository" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 12: --exclude and explicit paths ---

test_project_exclude_and_paths() {
  local test_name="check-refs --project: --exclude leaves files out of the check, explicit paths narrow the scan"
  setup_project "$test_name"
  local ok=0

  mkdir -p "$P/docs/archive" "$P/extra"
  printf '# Log\n\n- `GUIDE.md § Old Name`\n' > "$P/docs/CHANGELOG.md"
  printf '# Old\n\n- `GUIDE.md § Older Name`\n' > "$P/docs/archive/OLD.md"
  printf '# Live\n\n- `GUIDE.md § Paging`\n' > "$P/docs/LIVE.md"
  printf '# Extra\n\n- `GUIDE.md § Extra Gone`\n' > "$P/extra/E.md"

  run_refs --project "$P"
  assert_rc 1 || ok=1
  has "Old Name" || ok=1
  has "Older Name" || ok=1
  hasnt "Extra Gone" "files outside docs/ are not scanned by default" || ok=1

  run_refs --project "$P" --exclude CHANGELOG.md --exclude archive
  assert_rc 0 || ok=1
  has "references OK 1 / OK~ 0 / MISS 0 / excluded 2 (3 of 3 extracted accounted for)" || ok=1

  run_refs --project "$P" extra docs/LIVE.md
  assert_rc 1 || ok=1
  has "total: scanned 2 file(s)" || ok=1
  has 'MISS extra/E.md:3  `GUIDE.md § Extra Gone`' || ok=1
  hasnt "Old Name" || ok=1

  run_refs --project "$P" "$P/docs/LIVE.md"
  assert_rc 0 "absolute path" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 13: heading stub, unreadable files ---

test_project_stub_and_unread() {
  local test_name="check-refs --project: heading stub is a warning, unreadable files are exit 2"
  setup_project "$test_name"
  local ok=0

  printf '# Notes\n\n- `GUIDE.md § Moved section`\n' > "$P/docs/NOTES.md"
  run_refs --project "$P"
  assert_rc 0 "a stub is a warning only" || ok=1
  has 'OK   docs/NOTES.md:3  `GUIDE.md § Moved section` (resolves to a heading stub: "Moved section" →' || ok=1
  has "via heading stub: 1" || ok=1

  printf '# Bad\n\n\xff\xfe\n' > "$K/meta/BAD.md"
  printf '# Notes\n\n- `knowledge/meta/BAD.md § Bad`\n- `GUIDE.md § Gone`\n' > "$P/docs/NOTES.md"
  run_refs --project "$P"
  assert_rc 2 "incomplete wins over MISS" || ok=1
  has 'UNREAD docs/NOTES.md:3  `knowledge/meta/BAD.md § Bad` (cannot read the target knowledge/meta/BAD.md: UnicodeDecodeError' || ok=1
  has 'MISS docs/NOTES.md:4' "the rest is still checked" || ok=1
  has "==== result: incomplete" || ok=1

  printf '# Src\n\n\xff\n' > "$P/docs/BROKEN_SRC.md"
  printf '# Notes\n' > "$P/docs/NOTES.md"
  run_refs --project "$P"
  assert_rc 2 || ok=1
  has "UNREAD docs/BROKEN_SRC.md  (cannot read the file: UnicodeDecodeError" || ok=1
  run_refs --project "$P" --list
  assert_rc 2 "--list reports the unreadable source too" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 14: references into the distributed framework ---

test_project_framework_paths() {
  local test_name="check-refs --project: .claude/ paths fall back to the distributed framework"
  setup_project "$test_name"
  local ok=0

  cat > "$P/docs/NOTES.md" <<'EOF'
# Notes

- `.claude/skills/kaizen-editing-knowledge/SKILL.md § 編集後チェック`
- `.claude/skills/kaizen-editing-knowledge/SKILL.md § No Such Section Here`
- `.claude/skills/kaizen-no-such-skill/SKILL.md § X`
EOF

  run_refs --project "$P"
  assert_rc 1 || ok=1
  hasnt "docs/NOTES.md:3" "a skill of the real distribution resolves without a project link" || ok=1
  has "MISS docs/NOTES.md:4" || ok=1
  has 'MISS docs/NOTES.md:5  `.claude/skills/kaizen-no-such-skill/SKILL.md § X` (referenced file not found)' || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 15: this repository's own docs ---

test_real_repository_docs() {
  local test_name="check-refs --project: this repository's docs have no broken reference"
  setup_test_env "$test_name"
  local ok=0

  # A knowledge directory that does not exist in this repository's checkout is
  # replaced by an empty one, so the result does not depend on the developer's machine.
  mkdir -p "$TEST_HOME/empty-knowledge"
  run_refs --project "$KAIZEN_CLI_DIR" --knowledge "$TEST_HOME/empty-knowledge"
  assert_rc 0 || ok=1
  has "total: scanned" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 16: the distributed knowledge templates, as installed ---

test_distributed_templates_clean() {
  local test_name="check-refs --corpus: distributed knowledge templates are clean once installed (en, ja)"
  setup_test_env "$test_name"
  local ok=0

  local lang f
  for lang in en ja; do
    cp -R "$KAIZEN_CLI_DIR/framework/templates/$lang/knowledge" "$TEST_HOME/$lang"
    # setup installs `X.md.template` as `X.md`
    find "$TEST_HOME/$lang" -name '*.md.template' | while IFS= read -r f; do
      mv "$f" "${f%.template}"
    done
    run_refs --corpus "$TEST_HOME/$lang"
    assert_rc 0 || ok=1
    if [ "$REFS_OUT" != "none" ]; then
      echo "  FAIL: $lang templates should have no broken anchor or section reference"
      echo "$REFS_OUT" | sed 's/^/    | /'
      ok=1
    fi
  done

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 17: --corpus --staged (pre-commit gate of the knowledge repository) ---

test_corpus_staged_gate() {
  local test_name="check-refs --corpus --staged: added lines only, missing link targets, path filter, projects/ left out"
  setup_project "$test_name"
  local ok=0

  printf '# Src\n\n- old broken line: `aws/S3.md § Old Broken`\n' > "$K/meta/SRC.md"
  printf '# Other\n' > "$K/aws/OTHER.md"
  git -C "$P" -c init.defaultBranch=main init -q
  git -C "$P" add -A
  git -C "$P" commit -q -m init

  run_refs --corpus "$K" --staged
  assert_rc 0 || ok=1
  has "nothing was checked — no staged .md in scope (staged .md 0 / checked 0)" || ok=1

  # Sound additions: every form the gate reads
  cat >> "$K/meta/SRC.md" <<'EOF'
- link with an anchor: [a](../aws/S3.md#prefix-listing-semantics)
- link without an anchor: [b](../aws/S3.md)
- anchor into this file: [c](#src)
- section reference: `aws/S3.md § 設定方法`
- project path, cannot be judged here: `docs/PROJECT_SUMMARY.md § Not Checked`
> quoted line is not a reference: `aws/S3.md § Quoted Gone`
- into a registry copy; its headings are not ours to judge: [d](../projects/details/S3.md#whatever)
- a URL is not a file: [e](https://example.com/x.md)
- outside the knowledge tree, not ours to judge: [m](../../outside/NOPE.md)
EOF
  git -C "$P" add -A
  run_refs --corpus "$K" --staged
  assert_rc 0 || ok=1
  has "(lines added or changed in \`git diff --cached\`; staged .md 1 / checked 1)" || ok=1
  has "total: checked 1 file(s) / OK 4 / MISS 0" || ok=1
  hasnt "Old Broken" "a line that was not touched is not judged" || ok=1
  git -C "$P" commit -q -m sound

  # Broken additions, in two files; a registry mirror with a broken line too
  cat >> "$K/meta/SRC.md" <<'EOF'
- missing file behind an anchor: [f](./GONE.md#x)
- missing file: [g](../aws/GONE.md)
- missing heading: [h](../aws/S3.md#no-such-heading)
- missing heading in this file: [i](#no-such-heading)
- missing section: `aws/S3.md § New Broken`
- missing registry copy (inside the tree, so a broken link): [l](../projects/details/NOPE.md)
EOF
  printf -- '- [j](./GONE_TOO.md)\n' >> "$K/aws/OTHER.md"
  printf -- '- [k](./MIRROR_GONE.md) `aws/S3.md § Mirror Broken`\n' >> "$K/projects/details/S3.md"
  run_refs --corpus "$K" --staged
  assert_rc 0 "unstaged edits are not part of the gate" || ok=1
  git -C "$P" add -A
  run_refs --corpus "$K" --staged
  assert_rc 1 || ok=1
  has "staged .md 3 / checked 2 / out of scope 1" "the registry mirror is out of scope" || ok=1
  has 'MISS meta/SRC.md:13  `./GONE.md#x` (link target not found)' || ok=1
  has 'MISS meta/SRC.md:14  `../aws/GONE.md` (link target not found)' || ok=1
  has 'MISS meta/SRC.md:15  `../aws/S3.md#no-such-heading` (no matching heading)' || ok=1
  has 'MISS meta/SRC.md:16  `#no-such-heading` (no matching heading)' || ok=1
  has 'MISS meta/SRC.md:17  `aws/S3.md § New Broken` (no matching heading)' || ok=1
  has 'MISS meta/SRC.md:18  `../projects/details/NOPE.md` (link target not found)' || ok=1
  has 'MISS aws/OTHER.md:2  `./GONE_TOO.md` (link target not found)' || ok=1
  hasnt "Mirror" "projects/ is never judged" || ok=1
  hasnt "Old Broken" || ok=1
  has "total: checked 2 file(s) / OK 0 / MISS 7" || ok=1

  # With paths, only those files are judged (another session's staged file is not)
  run_refs --corpus "$K" --staged "$K/aws/OTHER.md"
  assert_rc 1 || ok=1
  has "staged .md 3 / checked 1 / out of scope 2" || ok=1
  has "total: checked 1 file(s) / OK 0 / MISS 1" || ok=1
  hasnt "SRC.md" || ok=1
  run_refs --corpus "$K" --staged aws/S3.md "$K/aws/REMOVED.md"
  assert_rc 0 "a path that is not staged, or no longer exists, only narrows the scope" || ok=1
  has "nothing was checked" || ok=1

  # The report mode is unchanged by the gate: it still leaves missing files to the link check
  run_refs --corpus "$K"
  assert_rc 0 || ok=1
  hasnt "GONE.md" "report mode does not report missing link targets" || ok=1
  has "S3.md#no-such-heading" || ok=1

  # Unreadable staged file: incomplete, not clean
  git -C "$P" commit -q -m broken
  printf '# Bad \377 bytes\n' > "$K/aws/BAD.md"
  git -C "$P" add -A
  run_refs --corpus "$K" --staged
  assert_rc 2 || ok=1
  has "UNREAD aws/BAD.md" || ok=1
  has "==== result: incomplete" || ok=1

  # Not a git repository
  mkdir -p "$TEST_HOME/nogit/meta"
  printf '# D\n' > "$TEST_HOME/nogit/meta/D.md"
  REFS_RC=0
  REFS_OUT=$(GIT_CEILING_DIRECTORIES="$TEST_HOME" python3 "$CHECK_REFS" --corpus "$TEST_HOME/nogit" --staged 2>&1) || REFS_RC=$?
  assert_rc 3 || ok=1
  has "--staged needs a git repository" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== kaizen-check-refs.py tests ==="
echo ""

test_legacy_check6_script
test_corpus_path_prefixed
test_corpus_clean_and_fences
test_corpus_errors
test_project_classification
test_project_clean_and_empty
test_project_pointer_lines
test_project_knowledge_dir
test_project_anchors
test_project_list
test_project_staged
test_project_exclude_and_paths
test_project_stub_and_unread
test_project_framework_paths
test_real_repository_docs
test_distributed_templates_clean
test_corpus_staged_gate

print_results
