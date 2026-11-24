#!/bin/bash
# Tests for framework/bin/kaizen-extract-section.sh
# Usage: bash tests/test_extract_section.sh
#
# Runs in isolated temp directories — does not affect the real environment.
# The fixtures reproduce the ways an ad-hoc awk range fails without an error:
# a `#` line inside a code fence, a heading that is a prefix of another one,
# regex metacharacters in a heading, and duplicated headings.

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

EXTRACT="$KAIZEN_CLI_DIR/framework/bin/kaizen-extract-section.sh"

# --- Helpers ---

# run_es <args...> — sets ES_OUT (stdout), ES_RC; stderr goes to $ES_ERR
run_es() {
  ES_ERR="$TEST_HOME/stderr"
  ES_RC=0
  ES_OUT=$(bash "$EXTRACT" "$@" 2>"$ES_ERR") || ES_RC=$?
}

# expect_out <label> <expected stdout> <expected rc> <args...>
expect_out() {
  local label="$1" want="$2" want_rc="$3"
  shift 3
  # $(...) drops trailing newlines, so drop them from the expectation too
  while [ "${want%$'\n'}" != "$want" ]; do want="${want%$'\n'}"; done
  run_es "$@"
  if [ "$ES_OUT" = "$want" ] && [ "$ES_RC" -eq "$want_rc" ]; then
    return 0
  fi
  echo "  FAIL: $label"
  echo "    rc=$ES_RC (want $want_rc) stdout=$(printf '%s' "$ES_OUT" | tr '\n' '|')"
  return 1
}

# expect_err <label> <expected rc> <stderr substring> <args...>
expect_err() {
  local label="$1" want_rc="$2" sub="$3"
  shift 3
  run_es "$@"
  if [ "$ES_RC" -eq "$want_rc" ] && grep -qF -- "$sub" "$ES_ERR"; then
    return 0
  fi
  echo "  FAIL: $label"
  echo "    rc=$ES_RC (want $want_rc) stderr=$(tr '\n' '|' < "$ES_ERR")"
  return 1
}

# expect_quiet <label> <stderr substring that must be absent> <args...>
expect_quiet() {
  local label="$1" sub="$2"
  shift 2
  run_es "$@"
  if [ "$ES_RC" -eq 0 ] && ! grep -qF -- "$sub" "$ES_ERR"; then
    return 0
  fi
  echo "  FAIL: $label"
  echo "    rc=$ES_RC stderr=$(tr '\n' '|' < "$ES_ERR")"
  return 1
}

# --- Fixtures ---

make_doc() {
  DOC="$TEST_HOME/doc.md"
  cat > "$DOC" <<'EOF'
# Title

## Alpha
alpha-1
alpha-2

## Alpha beta
ab-1

## Fenced
f-1
```bash
# not a heading (fence, column 0)
f-in-fence
```
f-2
- list item
  ```bash
  # not a heading (indented fence)
  f-in-indented-fence
  ```
f-3
~~~
# not a heading (tilde fence)
~~~
f-4
````markdown
```
# not a heading (inner triple inside quad fence)
```
````
f-5

### Nested level three
n3-1

## grep -n | cut (a.b) [x] ${n}+?
meta-1

## Parent
p-1

### Child one
c1-1

#### Grandchild
g-1

### Child two
c2-1

## Sibling
s-1

## Empty

## Dup
d-1

## Dup
d-2

## Trailing
t-1

## Closed ##
cl-1

## Env `TMPDIR` and `LANG`
env-1

####### Seven hashes is not a heading
EOF
}

make_fence_only() {
  FENCE_ONLY="$TEST_HOME/fence-only.md"
  cat > "$FENCE_ONLY" <<'EOF'
## Intro
i-1
```
## Ghost
ghost-body
```
## Real
r-1
EOF
}

# Two list-item fences with a heading between them: with only one, a fence
# opened by mistake closes by accident on the next fence line and the later
# headings are unaffected, so the test would stay green without the list-marker rule.
make_list_fence() {
  LIST_FENCE="$TEST_HOME/list-fence.md"
  cat > "$LIST_FENCE" <<'EOF'
## LF
lf-1
- ```bash
  # not a heading (fence right after list marker)
  ```
lf-2
## Mid
mid-1
1. ```
   # not a heading (fence after ordered marker)
   ```
lf-3
```inline``` is not a fence
lf-4
## After
af-1
EOF
}

make_backtick() {
  BACKTICK="$TEST_HOME/backtick.md"
  cat > "$BACKTICK" <<'EOF'
## Pick `a`
pa-1

## Pick a
pb-1

## Coll `x`
cx-1

## `Coll` x
cy-1
EOF
}

make_ja() {
  JA="$TEST_HOME/ja.md"
  cat > "$JA" <<'EOF'
# 題

## 設計判断
判断-1

## 設計判断の経緯
経緯-1

## Design Decisions（設計判断）
両言語-1

### 補足（a.b）[x]
補足-1

## --apply の手順
ap-1
EOF
}

# --- Test 1: basic contract ---

test_basic() {
  local test_name="extract: body only, stops at the next heading, whole-title match"
  setup_test_env "$test_name"
  local ok=0
  make_doc

  expect_out "body only" $'alpha-1\nalpha-2\n' 0 "$DOC" "Alpha" || ok=1
  expect_out "longer heading matches itself only" $'ab-1\n' 0 "$DOC" "Alpha beta" || ok=1
  expect_out "level-independent (### by the same call)" $'n3-1\n' 0 "$DOC" "Nested level three" || ok=1
  expect_out "default stops before a subheading" $'p-1\n' 0 "$DOC" "Parent" || ok=1
  expect_out "last section runs to end of file; 7 hashes is body text" \
    $'env-1\n\n####### Seven hashes is not a heading\n' 0 "$DOC" 'Env `TMPDIR` and `LANG`' || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: code fences ---

test_fences() {
  local test_name="extract: '#' lines inside code fences are neither start nor end"
  setup_test_env "$test_name"
  local ok=0
  make_doc
  make_fence_only

  expect_out "column-0, indented, tilde, and nested quad fences" \
$'f-1\n```bash\n# not a heading (fence, column 0)\nf-in-fence\n```\nf-2\n- list item\n  ```bash\n  # not a heading (indented fence)\n  f-in-indented-fence\n  ```\nf-3\n~~~\n# not a heading (tilde fence)\n~~~\nf-4\n````markdown\n```\n# not a heading (inner triple inside quad fence)\n```\n````\nf-5\n' \
    0 "$DOC" "Fenced" || ok=1
  expect_err "a heading inside a fence cannot be the start" 1 "heading not found" "$FENCE_ONLY" "Ghost" || ok=1
  expect_out "a heading inside a fence cannot be the end" $'i-1\n```\n## Ghost\nghost-body\n```\n' 0 "$FENCE_ONLY" "Intro" || ok=1
  expect_out "--list skips headings inside a fence" $'1: ## Intro\n7: ## Real' 0 --list "$FENCE_ONLY" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: fences opened right after a list marker, inline ```x``` ---

test_list_marker_fences() {
  local test_name="extract: fence after a list marker and inline triple-backtick code"
  setup_test_env "$test_name"
  local ok=0
  make_list_fence

  expect_out "heading after both list fences and the inline code is found" $'af-1\n' 0 "$LIST_FENCE" "After" || ok=1
  expect_out "closing line of a list fence is not read as an opening" \
$'lf-1\n- ```bash\n  # not a heading (fence right after list marker)\n  ```\nlf-2\n' 0 "$LIST_FENCE" "LF" || ok=1
  expect_out "heading between the two list fences keeps its own section" \
$'mid-1\n1. ```\n   # not a heading (fence after ordered marker)\n   ```\nlf-3\n```inline``` is not a fence\nlf-4\n' 0 "$LIST_FENCE" "Mid" || ok=1
  expect_out "--list sees all three headings" $'1: ## LF\n7: ## Mid\n15: ## After' 0 --list "$LIST_FENCE" || ok=1

  local want got
  want=$(sed -n '15,$p' "$LIST_FENCE" | wc -c | tr -d ' ')
  run_es --bytes "$LIST_FENCE"
  got=$(printf '%s\n' "$ES_OUT" | grep '^15: ' || true)
  if [ "$got" != "15: $want B  ## After" ]; then
    echo "  FAIL: --bytes should give the last heading its own section (got '$got', want '15: $want B  ## After')"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: metacharacters and title normalization ---

test_fixed_string_match() {
  local test_name="extract: heading is a fixed string (metacharacters, trailing blanks, closing #)"
  setup_test_env "$test_name"
  local ok=0
  make_doc

  expect_out "( ) [ ] | + ? \$ { } are literal" $'meta-1\n' 0 "$DOC" 'grep -n | cut (a.b) [x] ${n}+?' || ok=1
  expect_out "heading with trailing blanks" $'t-1\n' 0 "$DOC" "Trailing" || ok=1
  expect_out "closed heading (## X ##)" $'cl-1\n' 0 "$DOC" "Closed" || ok=1
  expect_err "prefix does not match; candidates are listed" 1 "Alpha beta" "$DOC" "Alpha b" || ok=1
  expect_err "passing '## Alpha' does not match (title only)" 1 "heading not found" "$DOC" "## Alpha" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 5: backticks are optional ---

test_backticks_optional() {
  local test_name="extract: backticks optional, exact match preferred, collision is exit 2"
  setup_test_env "$test_name"
  local ok=0
  make_doc
  make_backtick

  expect_out "reference text without backticks hits a heading with them" $'env-1\n\n####### Seven hashes is not a heading\n' 0 "$DOC" 'Env TMPDIR and LANG' || ok=1
  expect_err "such a match is noted on stderr" 0 "backticks ignored" "$DOC" 'Env TMPDIR and LANG' || ok=1
  expect_quiet "an exact match prints no note" "Note:" "$BACKTICK" 'Pick `a`' || ok=1
  expect_out "exact match wins over the backtick-insensitive one" $'pb-1\n' 0 "$BACKTICK" 'Pick a' || ok=1
  expect_out "needle with backticks hits only the heading with them" $'pa-1\n' 0 "$BACKTICK" 'Pick `a`' || ok=1
  expect_err "two headings equal once backticks are removed: exit 2 with line numbers" 2 "2 headings match (lines 7, 10)" "$BACKTICK" 'Coll x' || ok=1
  expect_out "collision returns no partial result" "" 2 "$BACKTICK" 'Coll x' || ok=1
  expect_err "candidates are searched with backticks removed" 1 "Env" "$DOC" 'TMPDIR and' || ok=1
  expect_out "--subtree accepts the backtick-less text too" $'env-1\n\n####### Seven hashes is not a heading\n' 0 --subtree "$DOC" 'Env TMPDIR and LANG' || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: error contract ---

test_error_contract() {
  local test_name="extract: not found = 1, several matches = 2, usage or file error = 3"
  setup_test_env "$test_name"
  local ok=0
  make_doc

  expect_err "not found without candidates points to --list" 1 "--list" "$DOC" "zzz-not-exist" || ok=1
  expect_out "not found: stdout is empty" "" 1 "$DOC" "zzz-not-exist" || ok=1
  expect_err "duplicate heading: exit 2 with line numbers" 2 "2 headings match (lines 57, 60)" "$DOC" "Dup" || ok=1
  expect_out "duplicate heading: stdout is empty" "" 2 "$DOC" "Dup" || ok=1
  expect_out "empty section: exit 0, no output" "" 0 "$DOC" "Empty" || ok=1
  expect_err "empty section is noted on stderr" 0 "section is empty" "$DOC" "Empty" || ok=1
  expect_err "missing file" 3 "file not found" "$TEST_HOME/nope.md" "Alpha" || ok=1
  expect_err "directory instead of a file" 3 "file not found" "$TEST_HOME" "Alpha" || ok=1
  expect_err "no heading given" 3 "Usage" "$DOC" || ok=1
  expect_err "empty heading" 3 "heading name is empty" "$DOC" "" || ok=1
  expect_err "no arguments" 3 "Usage" || ok=1
  expect_err "unknown option before the file" 3 "unknown option: --bogus" --bogus "$DOC" "Alpha" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: argument order ---

test_argument_order() {
  local test_name="extract: mode tokens in any position, extra arguments rejected"
  setup_test_env "$test_name"
  local ok=0
  make_doc
  make_fence_only
  make_ja

  expect_out "--subtree after the heading" $'c1-1\n\n#### Grandchild\ng-1\n' 0 "$DOC" "Child one" --subtree || ok=1
  expect_out "--list after the file" $'1: ## Intro\n7: ## Real' 0 "$FENCE_ONLY" --list || ok=1
  expect_err "extra argument is not dropped silently" 3 "unexpected extra argument: extra-arg" "$DOC" "Alpha" extra-arg || ok=1
  expect_err "--list with a heading" 3 "unexpected extra argument: Alpha" --list "$DOC" "Alpha" || ok=1
  expect_err "heading then --list" 3 "unexpected extra argument: Alpha" "$DOC" "Alpha" --list || ok=1
  expect_err "two modes" 3 "only one mode" --list "$DOC" --bytes || ok=1
  expect_err "unknown '--x' after the file is a heading title, not an option" 1 "heading not found: --bogus" "$DOC" "--bogus" || ok=1
  expect_out "heading that starts with '--'" $'ap-1\n' 0 "$JA" '--apply の手順' || ok=1
  expect_out "heading that starts with '--', with --subtree after it" $'ap-1\n' 0 "$JA" '--apply の手順' --subtree || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 8: --subtree ---

test_subtree() {
  local test_name="extract --subtree: includes subheadings, stops at the same or a higher level"
  setup_test_env "$test_name"
  local ok=0
  make_doc

  expect_out "## parent includes ### and ####, stops at the next ##" \
$'p-1\n\n### Child one\nc1-1\n\n#### Grandchild\ng-1\n\n### Child two\nc2-1\n' 0 --subtree "$DOC" "Parent" || ok=1
  expect_out "### parent stops at the next ###" $'c1-1\n\n#### Grandchild\ng-1\n' 0 --subtree "$DOC" "Child one" || ok=1
  expect_err "default mode notes that it stopped before a subheading" 0 "--subtree" "$DOC" "Parent" || ok=1
  expect_err "the note names the line and the subheading" 0 "line 43: ### Child one" "$DOC" "Parent" || ok=1
  expect_quiet "no note when the section ends at a same-level heading" "--subtree" "$DOC" "Alpha" || ok=1
  expect_quiet "no note with --subtree" "--subtree" --subtree "$DOC" "Parent" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 9: --list ---

test_list() {
  local test_name="extract --list: headings with line numbers, fenced lines excluded"
  setup_test_env "$test_name"
  local ok=0
  make_doc

  run_es --list "$DOC"
  [ "$ES_RC" -eq 0 ] || { echo "  FAIL: --list should exit 0, got $ES_RC"; ok=1; }
  assert_output_not_contains "$ES_OUT" "not a heading" "fenced '#' lines must not be listed" || ok=1
  assert_output_not_contains "$ES_OUT" "Seven hashes" "7 hashes is not a heading" || ok=1
  assert_output_contains "$ES_OUT" "3: ## Alpha" "line-numbered heading" || ok=1
  assert_output_contains "$ES_OUT" "34: ### Nested level three" "level-3 heading" || ok=1
  local count
  count=$(printf '%s\n' "$ES_OUT" | grep -c '^[0-9][0-9]*: #' || true)
  if [ "$count" -ne 17 ]; then
    echo "  FAIL: fixture has 17 headings, --list printed $count"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 10: --bytes ---

test_bytes() {
  local test_name="extract --bytes: flat bytes per heading, preamble row, total equals wc -c"
  setup_test_env "$test_name"
  local ok=0

  local f="$TEST_HOME/bytes.md"
  printf -- '---\nk: v\n---\n# \xe9\xa1\x8c\n\xe3\x81\x82\n\n## A\nx\n```bash\n# c\n```\n\n## B\ny\n' > "$f"
  expect_out "preamble row, multibyte text counted in bytes, fenced '#' is not a section" \
    $'1: 13 B  (preamble: before the first heading)\n4: 11 B  # \xe9\xa1\x8c\n7: 24 B  ## A\n13: 7 B  ## B\ntotal: 55 B' \
    0 --bytes "$f" || ok=1
  # The same under a UTF-8 locale of the caller: bytes, not characters
  local out_utf8
  out_utf8=$(LC_ALL=en_US.UTF-8 bash "$EXTRACT" --bytes "$f" 2>/dev/null | grep '^4: ' || true)
  if [ "$out_utf8" != $'4: 11 B  # \xe9\xa1\x8c' ]; then
    echo "  FAIL: byte count must not depend on the caller's locale (got '$out_utf8')"
    ok=1
  fi

  local noeol="$TEST_HOME/noeol.md"
  printf -- '## Z\nz' > "$noeol"
  expect_out "no trailing newline: total is the real size, empty preamble omitted" $'1: 6 B  ## Z\ntotal: 6 B' 0 --bytes "$noeol" || ok=1
  expect_out "--bytes after the file" $'1: 6 B  ## Z\ntotal: 6 B' 0 "$noeol" --bytes || ok=1
  expect_out "no trailing newline: the last body line is still extracted" "z" 0 "$noeol" "Z" || ok=1

  local empty="$TEST_HOME/empty.md"
  : > "$empty"
  expect_out "empty file" "total: 0 B" 0 --bytes "$empty" || ok=1
  expect_out "empty file: --list prints nothing" "" 0 --list "$empty" || ok=1
  expect_err "empty file: extraction is 'not found'" 1 "heading not found" "$empty" "A" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 11: CRLF ---

test_crlf() {
  local test_name="extract: CRLF input (CR ignored for detection, kept in output and byte counts)"
  setup_test_env "$test_name"
  local ok=0

  local f="$TEST_HOME/crlf.md"
  printf -- '# T\r\n## A\r\na-1\r\n```\r\n## Ghost\r\n```\r\na-2\r\n## B\r\nb-1\r\n' > "$f"
  # Compared through files: $(...) would hide the CR of the last line
  printf 'a-1\r\n```\r\n## Ghost\r\n```\r\na-2\r\n' > "$TEST_HOME/crlf.want"
  local rc=0
  bash "$EXTRACT" "$f" "A" > "$TEST_HOME/crlf.got" 2>/dev/null || rc=$?
  if [ "$rc" -ne 0 ] || ! cmp -s "$TEST_HOME/crlf.got" "$TEST_HOME/crlf.want"; then
    echo "  FAIL: CRLF section should match byte for byte (rc=$rc)"
    od -c "$TEST_HOME/crlf.got" | sed 's/^/    | /'
    ok=1
  fi
  expect_out "--list on CRLF" $'1: # T\n2: ## A\n8: ## B' 0 --list "$f" || ok=1
  expect_out "--bytes on CRLF counts the CR" $'1: 5 B  # T\n2: 36 B  ## A\n8: 11 B  ## B\ntotal: 52 B' 0 --bytes "$f" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 12: Japanese headings ---

test_japanese_headings() {
  local test_name="extract: Japanese and bilingual headings"
  setup_test_env "$test_name"
  local ok=0
  make_ja

  expect_out "Japanese heading, no prefix match against a longer one" $'判断-1\n' 0 "$JA" "設計判断" || ok=1
  expect_out "longer Japanese heading" $'経緯-1\n' 0 "$JA" "設計判断の経緯" || ok=1
  expect_out "bilingual heading with full-width parentheses" $'両言語-1\n' 0 "$JA" "Design Decisions（設計判断）" || ok=1
  expect_err "English stem alone does not match the bilingual heading" 1 "Design Decisions（設計判断）" "$JA" "Design Decisions" || ok=1
  expect_out "Japanese heading with ASCII metacharacters" $'補足-1\n' 0 "$JA" "補足（a.b）[x]" || ok=1
  expect_out "--subtree over Japanese headings" $'両言語-1\n\n### 補足（a.b）[x]\n補足-1\n' 0 --subtree "$JA" "Design Decisions（設計判断）" || ok=1

  local total
  run_es --bytes "$JA"
  total=$(printf '%s\n' "$ES_OUT" | tail -1 | sed 's/[^0-9]//g')
  if [ "$total" != "$(wc -c < "$JA" | tr -d ' ')" ]; then
    echo "  FAIL: --bytes total ($total) should equal wc -c"
    ok=1
  fi
  local sum
  sum=$(printf '%s\n' "$ES_OUT" | sed '$d' | sed 's/^[0-9]*: \([0-9]*\) B.*/\1/' | awk '{ s += $1 } END { print s + 0 }')
  if [ "$sum" != "$total" ]; then
    echo "  FAIL: per-heading bytes ($sum) should add up to the total ($total)"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 13: unreadable file ---

test_unreadable_file() {
  local test_name="extract: unreadable file is exit 3 in every mode"
  setup_test_env "$test_name"
  local ok=0

  local f="$TEST_HOME/unreadable.md"
  printf -- '## A\na-1\n' > "$f"
  chmod 000 "$f"
  if [ -r "$f" ]; then
    echo "  (skipped: cannot create an unreadable file here, e.g. running as root)"
  else
    expect_err "extraction" 3 "cannot read file" "$f" "A" || ok=1
    expect_err "--list" 3 "cannot read file" --list "$f" || ok=1
    expect_err "--bytes" 3 "cannot read file" --bytes "$f" || ok=1
  fi
  chmod 644 "$f"

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 14: reader closes the pipe first ---

# piped_rc <default|ignored> <extract|list|bytes> <big file> <many-headings file>
# Prints the script's exit code when its output is piped to `head -1`.
# A function rather than an inline $(...) block: bash 3.2 cannot parse a
# `case` inside a command substitution.
piped_rc() {
  set +e
  if [ "$1" = ignored ]; then trap '' PIPE; fi
  case "$2" in
    extract) bash "$EXTRACT" "$3" "Big" 2>"$TEST_HOME/err" | head -1 > /dev/null; echo "${PIPESTATUS[0]}" ;;
    list)    bash "$EXTRACT" --list "$4" 2>"$TEST_HOME/err" | head -1 > /dev/null; echo "${PIPESTATUS[0]}" ;;
    bytes)   bash "$EXTRACT" --bytes "$4" 2>"$TEST_HOME/err" | head -1 > /dev/null; echo "${PIPESTATUS[0]}" ;;
  esac
}

test_reader_closes_pipe() {
  local test_name="extract: '| head' closing the pipe early is not reported as a failure"
  setup_test_env "$test_name"
  local ok=0

  # Larger than a pipe buffer, so awk is still writing when head exits
  local big="$TEST_HOME/big.md" many="$TEST_HOME/many.md"
  { echo "## Big"; seq 1 200000; echo "## End"; } > "$big"
  seq 1 20000 | sed 's/^/## H/' > "$many"

  # Two ways awk learns that the reader is gone: it is killed by SIGPIPE, or
  # (BSD awk, or SIGPIPE ignored by the caller) its write fails and it exits 2
  # with a message. "ignored" forces the second way on every platform.
  local m sig rc
  for sig in default ignored; do
    for m in extract list bytes; do
      rc=$(piped_rc "$sig" "$m" "$big" "$many")
      if [ "$rc" != 0 ] || [ -s "$TEST_HOME/err" ]; then
        echo "  FAIL: $m piped to head (SIGPIPE $sig) should exit 0 with empty stderr (rc=$rc, stderr=$(head -c 200 "$TEST_HOME/err"))"
        ok=1
      fi
    done
  done

  # A real awk failure is still exit 3, and stderr of a normal run still arrives
  run_es "$big" "No Such Heading"
  [ "$ES_RC" -eq 1 ] || { echo "  FAIL: not-found should stay exit 1, got $ES_RC"; ok=1; }
  grep -qF "heading not found" "$ES_ERR" || { echo "  FAIL: stderr of awk must be passed through"; ok=1; }

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== kaizen-extract-section.sh tests ==="
echo ""

test_basic
test_fences
test_list_marker_fences
test_fixed_string_match
test_backticks_optional
test_error_contract
test_argument_order
test_subtree
test_list
test_bytes
test_crlf
test_japanese_headings
test_unreadable_file
test_reader_closes_pipe

print_results
