#!/bin/bash
# Tests for framework/bin/kaizen-search-knowledge.sh
# Usage: bash tests/test_search_knowledge.sh
#
# Runs in isolated temp directories — does not affect the real environment.
# The script finds the framework next to itself, so each test runs a copy of it
# inside a fixture checkout (framework/bin + framework/.claude) and a fixture
# knowledge directory reached through a project's knowledge/ symlink.
#
# The fixtures reproduce the ways a search answers "0" for something that is
# there: a symlinked knowledge directory, a rule that lives in a skill, a regex
# metacharacter in the term, a failing grep, and an area that does not exist.

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

BIN="$KAIZEN_CLI_DIR/framework/bin"
FW="$KAIZEN_CLI_DIR/framework/.claude"

# --- Helpers ---

# run_sk <args...> — runs the fixture copy from $SK_CWD (default: the project).
# Sets SK_OUT (stdout), SK_RC; stderr goes to $SK_ERR.
run_sk() {
  SK_ERR="$TEST_HOME/stderr"
  SK_RC=0
  SK_OUT=$(cd "${SK_CWD:-$PROJ}" && bash "$SEARCH" "$@" 2>"$SK_ERR") || SK_RC=$?
}

# expect_rc <want> [label]
expect_rc() {
  if [ "$SK_RC" -eq "$1" ]; then return 0; fi
  echo "  FAIL: ${2:-exit code} should be $1, got $SK_RC"
  echo "    stdout=$(printf '%s' "$SK_OUT" | tr '\n' '|')"
  echo "    stderr=$(tr '\n' '|' < "$SK_ERR")"
  return 1
}

# count_lines <fixed string> — lines of SK_OUT that contain it
count_lines() {
  printf '%s\n' "$SK_OUT" | grep -cF -- "$1" || true
}

# rep <string> <n> — the string n times (no seq: not everywhere)
rep() {
  local s="" i=0
  while [ "$i" -lt "$2" ]; do s="$s$1"; i=$((i + 1)); done
  printf '%s' "$s"
}

# --- Fixtures ---

# make_fixture — a checkout ($CLI), a knowledge store ($STORE, registry
# "default" = $KDIR), and a project ($PROJ) whose knowledge/ links to it.
make_fixture() {
  CLI="$TEST_HOME/cli"
  STORE="$TEST_HOME/store"
  KDIR="$STORE/default"
  PROJ="$TEST_HOME/proj"
  SEARCH="$CLI/framework/bin/kaizen-search-knowledge.sh"
  SK_CWD=""

  mkdir -p "$CLI/framework/bin" \
           "$CLI/framework/.claude/skills/kaizen-demo" \
           "$CLI/framework/.claude/commands" \
           "$CLI/framework/.claude/agents"
  cp "$BIN/kaizen-search-knowledge.sh" "$BIN/kaizen-extract-section.sh" "$CLI/framework/bin/"
  printf '## Rule\nfoo in skill\n' > "$CLI/framework/.claude/skills/kaizen-demo/SKILL.md"
  printf 'no match here\n' > "$CLI/framework/.claude/commands/kaizen-x.md"
  printf '## Agent\nS3 Connector\n' > "$CLI/framework/.claude/agents/kaizen-a.md"

  mkdir -p "$KDIR/aws/projects" "$KDIR/meta" "$KDIR/tools" "$KDIR/projects/learnings"
  cat > "$KDIR/aws/A.md" <<'EOF'
intro foo-pre
# Top
## Alpha
foo bar
```
# not heading
foo in fence
```
## Beta
baz foo
EOF
  cat > "$KDIR/meta/NOTE.md" <<'EOF'
## One
qux
### Two
foo twice foo
a.b literal
**bold** word
braces {} here
axb bait
EOF
  cat > "$KDIR/meta/OTHER.md" <<'EOF'
## Only
axb here
bold word
## 日本語 節
日本語の見出し語を含む行
EOF
  printf '## Win\r\nfoo crlf\r\n' > "$KDIR/meta/CRLF.md"
  printf '# comment\necho foo\n' > "$KDIR/tools/c.sh"
  printf '\000\001binary foo\n' > "$KDIR/blob.bin"
  # projects/ at the top is the registry mirror (excluded); a directory of the
  # same name further down is ordinary knowledge (scanned).
  printf '## L\nfoo mirror\n' > "$KDIR/projects/learnings/p1.md"
  printf '## Nested\nfoo nested\n' > "$KDIR/aws/projects/KEEP.md"

  mkdir -p "$PROJ/docs" "$PROJ/.claude/skills/own"
  ln -s "$KDIR" "$PROJ/knowledge"
  ln -s "$CLI/framework/.claude/skills/kaizen-demo" "$PROJ/.claude/skills/kaizen-demo"
  printf '## Decided\nfoo decided\n' > "$PROJ/docs/NOTES.md"
  printf '## Own\nfoo own\n' > "$PROJ/.claude/skills/own/SKILL.md"
}

# --- Test 1: areas, [K], [H] ---

test_basic() {
  local test_name="search: knowledge through the symlink and the framework, with sections"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  run_sk foo
  expect_rc 0 || ok=1
  assert_output_contains "$SK_OUT" "[kaizen-search-knowledge]" || ok=1
  assert_output_contains "$SK_OUT" "[/kaizen-search-knowledge]" || ok=1
  assert_output_contains "$SK_OUT" "status=ok" || ok=1

  # The knowledge area is the real directory behind the project's symlink.
  local real
  real="$(cd "$KDIR" && pwd -P)"
  assert_output_contains "$SK_OUT" "area: knowledge/ -> $real (7 files, projects/ excluded)" || ok=1
  real="$(cd "$CLI/framework/.claude" && pwd -P)"
  assert_output_contains "$SK_OUT" "area: framework/ -> $real (3 files in skills, commands, agents)" || ok=1

  assert_output_contains "$SK_OUT" '[K] "foo": 6 file(s)' || ok=1
  assert_output_contains "$SK_OUT" "  knowledge/aws/A.md" || ok=1
  assert_output_contains "$SK_OUT" "  knowledge/meta/NOTE.md" || ok=1
  assert_output_contains "$SK_OUT" "  knowledge/tools/c.sh" \
    "files that are not Markdown are searched too" || ok=1
  assert_output_contains "$SK_OUT" "  framework/skills/kaizen-demo/SKILL.md" \
    "a rule written in a skill must be found" || ok=1
  assert_output_not_contains "$SK_OUT" "blob.bin" "binary files are left out" || ok=1

  # The whole list, in a fixed order: knowledge first, sorted inside each area.
  local k_block want
  k_block="$(printf '%s\n' "$SK_OUT" | sed -n '/^\[K\] "foo"/,/^\[H\]/p' | sed '$d')"
  want='[K] "foo": 6 file(s)
  knowledge/aws/A.md
  knowledge/aws/projects/KEEP.md
  knowledge/meta/CRLF.md
  knowledge/meta/NOTE.md
  knowledge/tools/c.sh
  framework/skills/kaizen-demo/SKILL.md'
  if [ "$k_block" != "$want" ]; then
    echo "  FAIL: the [K] list differs from the expected one:"
    printf '%s\n' "$k_block" | sed 's/^/    | /'
    ok=1
  fi

  assert_output_contains "$SK_OUT" "[H] knowledge/aws/A.md (4 line(s))" || ok=1
  assert_output_contains "$SK_OUT" "  L1 (before the first heading): intro foo-pre" || ok=1
  assert_output_contains "$SK_OUT" "  L4 (§ Alpha): foo bar" || ok=1
  assert_output_contains "$SK_OUT" "  L7 (§ Alpha): foo in fence" \
    "a # line inside a code fence is not a heading" || ok=1
  assert_output_contains "$SK_OUT" "  L10 (§ Beta): baz foo" || ok=1
  assert_output_contains "$SK_OUT" "  L4 (§ Two): foo twice foo" || ok=1
  assert_output_contains "$SK_OUT" "  L2: echo foo" \
    "a # comment in a script is not a heading" || ok=1
  assert_output_contains "$SK_OUT" "  L2 (§ Win): foo crlf" || ok=1
  if printf '%s' "$SK_OUT" | grep -q "$(printf '\r')"; then
    echo "  FAIL: a carriage return of a CRLF file reached the output"
    ok=1
  fi

  # A hit on the heading line itself belongs to that heading.
  run_sk Alpha
  assert_output_contains "$SK_OUT" "  L3 (§ Alpha): ## Alpha" || ok=1

  # --knowledge names the directory explicitly; the result is the same.
  SK_CWD="$TEST_HOME"
  run_sk --knowledge "$KDIR" foo
  expect_rc 0 "--knowledge" || ok=1
  assert_output_contains "$SK_OUT" '[K] "foo": 6 file(s)' || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: projects/ ---

test_projects_excluded() {
  local test_name="search: projects/ at the top of the knowledge directory is not scanned"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  run_sk foo mirror
  expect_rc 0 || ok=1
  assert_output_not_contains "$SK_OUT" "p1.md" "the registry mirror must not be a hit" || ok=1
  assert_output_contains "$SK_OUT" '[K] "mirror": 0 file(s)' || ok=1
  assert_output_contains "$SK_OUT" "  knowledge/aws/projects/KEEP.md" \
    "only projects/ at the top is the mirror" || ok=1
  assert_output_contains "$SK_OUT" "  L2 (§ Nested): foo nested" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: fixed strings ---

test_fixed_string() {
  local test_name="search: keywords are fixed strings"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  run_sk a.b
  assert_output_contains "$SK_OUT" '[K] "a.b": 1 file(s)' "a.b must not match axb" || ok=1
  assert_output_contains "$SK_OUT" "[H] knowledge/meta/NOTE.md (1 line(s))" \
    "the lines are matched as fixed strings too (axb is in the same file)" || ok=1
  assert_output_not_contains "$SK_OUT" "OTHER.md" || ok=1

  run_sk '**bold**'
  assert_output_contains "$SK_OUT" '[K] "**bold**": 1 file(s)' || ok=1
  assert_output_contains "$SK_OUT" "  L6 (§ Two): **bold** word" || ok=1

  run_sk '{}'
  expect_rc 0 "{} as a keyword" || ok=1
  assert_output_contains "$SK_OUT" '[K] "{}": 1 file(s)' || ok=1

  run_sk -- --dash-keyword
  expect_rc 0 "a keyword after --" || ok=1
  assert_output_contains "$SK_OUT" '[K] "--dash-keyword": 0 file(s)' || ok=1

  run_sk 見出し語
  assert_output_contains "$SK_OUT" '[K] "見出し語": 1 file(s)' || ok=1
  assert_output_contains "$SK_OUT" "  L5 (§ 日本語 節): 日本語の見出し語を含む行" || ok=1

  # Case: exact by default, ASCII-insensitive with -i.
  run_sk "s3 connector"
  assert_output_contains "$SK_OUT" '[K] "s3 connector": 0 file(s)' || ok=1
  run_sk -i "s3 connector"
  assert_output_contains "$SK_OUT" '[K] "s3 connector": 1 file(s)' || ok=1
  assert_output_contains "$SK_OUT" "  L2 (§ Agent): S3 Connector" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: several keywords, no hit ---

test_keywords_and_zero() {
  local test_name="search: each keyword is reported; 0 files is exit 0 and says what it is not"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  run_sk foo qux zzz-none
  expect_rc 0 "a keyword without a hit" || ok=1
  assert_output_contains "$SK_OUT" '[K] "foo": 6 file(s)' || ok=1
  assert_output_contains "$SK_OUT" '[K] "qux": 1 file(s)' || ok=1
  assert_output_contains "$SK_OUT" '[K] "zzz-none": 0 file(s) — not proof of absence' || ok=1
  assert_output_contains "$SK_OUT" "status=ok" || ok=1

  # A file hit by two keywords gets one [H] entry, with the lines of both.
  if [ "$(count_lines "[H] knowledge/meta/NOTE.md")" != 1 ]; then
    echo "  FAIL: NOTE.md should have exactly one [H] entry"
    ok=1
  fi
  assert_output_contains "$SK_OUT" "[H] knowledge/meta/NOTE.md (2 line(s))" || ok=1
  assert_output_contains "$SK_OUT" "  L2 (§ One): qux" || ok=1

  # Nothing found at all: still a result, still exit 0.
  run_sk zzz-none
  expect_rc 0 "no hit at all" || ok=1
  assert_output_contains "$SK_OUT" "status=ok" || ok=1
  assert_output_not_contains "$SK_OUT" "[H]" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 5: limits are announced ---

test_limits() {
  local test_name="search: --max-files and --max-lines say what they left out"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  run_sk --max-files 1 foo
  assert_output_contains "$SK_OUT" "[H] (the first 1 of 6 files" || ok=1
  assert_output_contains "$SK_OUT" '[K] "foo": 6 file(s)' "[K] is never cut" || ok=1
  assert_output_contains "$SK_OUT" "  knowledge/tools/c.sh" "[K] is never cut" || ok=1
  if [ "$(count_lines " line(s))")" != 1 ]; then
    echo "  FAIL: --max-files 1 should print one [H] entry, got $(count_lines " line(s))")"
    ok=1
  fi

  run_sk --max-lines 2 foo
  assert_output_contains "$SK_OUT" "[H] knowledge/aws/A.md (4 line(s))" || ok=1
  assert_output_contains "$SK_OUT" "  ... 2 more line(s) (raise --max-lines)" || ok=1
  assert_output_not_contains "$SK_OUT" "L10 (§ Beta)" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: long lines ---

test_clip() {
  local test_name="search: a long line is clipped on a character boundary"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  # The cut is at 240 bytes. The ASCII prefix shifts where it lands inside a
  # 3-byte, 4-byte, or 2-byte character, so every offset is exercised.
  local ja emoji latin
  ja="$(rep あ 200)"
  emoji="$(rep 😀 100)"
  latin="$(rep é 200)"
  {
    printf '## Long\n'
    printf 'clipkey%s\n' "$ja"
    printf 'clipkey1%s\n' "$ja"
    printf 'clipkey12%s\n' "$ja"
    printf 'clipkey%s\n' "$emoji"
    printf 'clipkey1%s\n' "$emoji"
    printf 'clipkey12%s\n' "$emoji"
    printf 'clipkey123%s\n' "$emoji"
    printf 'clipkey%s\n' "$latin"
    printf 'clipkey12%s\n' "$latin"
    printf 'clipkey short\n'
  } > "$KDIR/meta/LONG.md"

  run_sk --max-lines 20 clipkey
  expect_rc 0 || ok=1

  local ln ch line body rest bytes
  for ln in 2 3 4 5 6 7 8 9 10; do
    case "$ln" in
      2|3|4) ch="あ" ;;
      5|6|7|8) ch="😀" ;;
      *) ch="é" ;;
    esac
    line="$(printf '%s\n' "$SK_OUT" | grep -F "  L$ln (§ Long): " || true)"
    body="${line#*): }"
    if [ -z "$line" ] || [ "${body%…}" = "$body" ]; then
      echo "  FAIL: L$ln should be printed and end with the ellipsis: $line"
      ok=1
      continue
    fi
    body="${body%…}"
    bytes=$(printf '%s' "$body" | wc -c | tr -d ' ')
    if [ "$bytes" -gt 240 ] || [ "$bytes" -lt 236 ]; then
      echo "  FAIL: L$ln should keep 236-240 bytes, got $bytes"
      ok=1
    fi
    # What is left after the prefix must be whole characters only.
    rest="${body#clipkey}"
    rest="${rest#1}"; rest="${rest#2}"; rest="${rest#3}"
    rest="${rest//$ch/}"
    if [ -n "$rest" ]; then
      echo "  FAIL: L$ln was cut inside a character ($(printf '%s' "$rest" | wc -c | tr -d ' ') stray byte(s))"
      ok=1
    fi
  done
  assert_output_contains "$SK_OUT" "  L11 (§ Long): clipkey short" || ok=1
  assert_output_not_contains "$SK_OUT" "clipkey short…" "a short line is not clipped" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: [S] ---

test_uncommitted() {
  local test_name="search: [S] lists uncommitted knowledge, and a directory without git is not an error"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  # Not a git repository: the search is complete, [S] says why it is empty.
  run_sk foo
  expect_rc 0 "knowledge directory without git" || ok=1
  assert_output_contains "$SK_OUT" "[S] not checked: the knowledge directory is not a git repository" || ok=1
  assert_output_contains "$SK_OUT" "status=ok" || ok=1

  # The repository is the store; the knowledge directory is one registry in it.
  mkdir -p "$STORE/other"
  printf 'x\n' > "$STORE/other/X.md"
  git -C "$STORE" init -q
  git -C "$STORE" add -A
  git -C "$STORE" commit -q -m "base"

  run_sk foo
  expect_rc 0 "clean repository" || ok=1
  assert_output_contains "$SK_OUT" "[S] uncommitted changes in the knowledge repository: none" || ok=1

  printf 'edited\n' >> "$KDIR/meta/NOTE.md"
  printf 'new\n' > "$KDIR/aws/NEW.md"
  printf '新規\n' > "$KDIR/aws/日本語.md"
  mkdir -p "$KDIR/newdir"
  printf 'in a new directory\n' > "$KDIR/newdir/N.md"
  printf 'mirror edit\n' >> "$KDIR/projects/learnings/p1.md"
  printf 'other registry\n' >> "$STORE/other/X.md"

  run_sk foo
  expect_rc 0 "uncommitted changes are information, not a failure" || ok=1
  assert_output_contains "$SK_OUT" "[S] uncommitted changes in the knowledge repository: 4 " || ok=1
  assert_output_contains "$SK_OUT" "  ?? newdir/N.md" "a new directory is listed file by file" || ok=1
  assert_output_contains "$SK_OUT" "   M meta/NOTE.md" || ok=1
  assert_output_contains "$SK_OUT" "  ?? aws/NEW.md" || ok=1
  assert_output_contains "$SK_OUT" "  ?? aws/日本語.md" "non-ASCII paths are printed as they are" || ok=1
  local s_part
  s_part="$(printf '%s\n' "$SK_OUT" | sed -n '/^\[S\]/,$p')"
  assert_output_not_contains "$s_part" "p1.md" "projects/ is left out of [S]" || ok=1
  assert_output_not_contains "$s_part" "X.md" "another registry is left out of [S]" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 8: --also ---

test_also() {
  local test_name="search: --also adds a directory and does not follow links inside it"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  run_sk --also docs --also ./.claude/skills/ foo
  expect_rc 0 || ok=1
  assert_output_contains "$SK_OUT" "area: docs/ -> " || ok=1
  assert_output_contains "$SK_OUT" "area: .claude/skills/ -> " || ok=1
  assert_output_contains "$SK_OUT" '[K] "foo": 8 file(s)' || ok=1
  assert_output_contains "$SK_OUT" "  docs/NOTES.md" || ok=1
  assert_output_contains "$SK_OUT" "  L2 (§ Decided): foo decided" || ok=1
  assert_output_contains "$SK_OUT" "  .claude/skills/own/SKILL.md" \
    "the project's own skill is found" || ok=1
  # The linked framework skill is reported once, at its source.
  assert_output_not_contains "$SK_OUT" ".claude/skills/kaizen-demo/SKILL.md" || ok=1
  assert_output_contains "$SK_OUT" "  framework/skills/kaizen-demo/SKILL.md" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 9: what was not scanned ---

test_partial() {
  local test_name="search: an area that cannot be scanned is named, and the exit code is 1"
  setup_test_env "$test_name"
  local ok=0
  make_fixture
  mkdir -p "$TEST_HOME/elsewhere"

  # No knowledge/ here: the framework is still searched, the gap is stated.
  SK_CWD="$TEST_HOME/elsewhere"
  run_sk foo
  expect_rc 1 "no knowledge/ in the current directory" || ok=1
  assert_output_contains "$SK_OUT" "not-scanned: knowledge/ (no knowledge/ in the current directory" || ok=1
  assert_output_contains "$SK_OUT" '[K] "foo": 1 file(s)' || ok=1
  assert_output_contains "$SK_OUT" "  framework/skills/kaizen-demo/SKILL.md" || ok=1
  assert_output_contains "$SK_OUT" "[S] not checked: the knowledge directory was not scanned" || ok=1
  assert_output_contains "$SK_OUT" "status=partial" || ok=1

  run_sk --knowledge "$TEST_HOME/nope" foo
  expect_rc 1 "--knowledge that does not exist" || ok=1
  assert_output_contains "$SK_OUT" "not-scanned: knowledge/ (no such directory: $TEST_HOME/nope)" || ok=1

  SK_CWD=""
  run_sk --also nope foo
  expect_rc 1 "--also that does not exist" || ok=1
  assert_output_contains "$SK_OUT" "not-scanned: nope/ (no such directory)" || ok=1
  assert_output_contains "$SK_OUT" '[K] "foo": 6 file(s)' "the other areas are still searched" || ok=1
  assert_output_contains "$SK_OUT" "status=partial" || ok=1

  # A framework without one of its three directories.
  rm -rf "$CLI/framework/.claude/agents"
  run_sk foo
  expect_rc 1 "framework/agents missing" || ok=1
  assert_output_contains "$SK_OUT" "not-scanned: framework/agents " || ok=1
  assert_output_contains "$SK_OUT" "files in skills, commands)" || ok=1

  # Nothing at all to scan: a usage-level error, no [K] line.
  mkdir -p "$TEST_HOME/bare/bin"
  cp "$BIN/kaizen-search-knowledge.sh" "$TEST_HOME/bare/bin/"
  SEARCH="$TEST_HOME/bare/bin/kaizen-search-knowledge.sh"
  SK_CWD="$TEST_HOME/elsewhere"
  run_sk foo
  expect_rc 3 "nothing to scan" || ok=1
  assert_output_contains "$SK_OUT" "error=nothing to scan" || ok=1
  assert_output_contains "$SK_OUT" "status=error" || ok=1
  assert_output_not_contains "$SK_OUT" "[K]" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 10: a file that cannot be read ---

test_unreadable_file() {
  local test_name="search: an unreadable file is a warning and status=partial"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  local f="$KDIR/meta/LOCKED.md"
  printf '## Locked\nfoo locked\n' > "$f"
  chmod 000 "$f"
  if [ -r "$f" ]; then
    echo "  (skipped: cannot create an unreadable file here, e.g. running as root)"
  else
    run_sk foo
    expect_rc 1 "unreadable file" || ok=1
    assert_output_contains "$SK_OUT" "warning: " || ok=1
    assert_output_contains "$SK_OUT" "LOCKED.md" "the warning names the file" || ok=1
    assert_output_contains "$SK_OUT" "status=partial" || ok=1
    assert_output_contains "$SK_OUT" '[K] "foo": 6 file(s)' "the readable files are still searched" || ok=1
  fi
  chmod 644 "$f"

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 11: a grep that does not work ---

test_broken_grep() {
  local test_name="search: a failing grep is exit 2, not 0 files"
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  # Empty output and exit 1 — exactly what "no match" looks like.
  mkdir -p "$TEST_HOME/fakebin"
  printf '#!/bin/sh\nexit 1\n' > "$TEST_HOME/fakebin/grep"
  chmod +x "$TEST_HOME/fakebin/grep"

  SK_ERR="$TEST_HOME/stderr"
  SK_RC=0
  SK_OUT=$(cd "$PROJ" && PATH="$TEST_HOME/fakebin:$PATH" bash "$SEARCH" foo 2>"$SK_ERR") || SK_RC=$?
  expect_rc 2 "broken grep" || ok=1
  assert_output_contains "$SK_OUT" "error=find/grep did not find a known string" || ok=1
  assert_output_contains "$SK_OUT" "status=error" || ok=1
  assert_output_not_contains "$SK_OUT" "[K]" "no result line may be printed" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 12: usage errors ---

test_usage_errors() {
  local test_name="search: usage errors are exit 3 with error="
  setup_test_env "$test_name"
  local ok=0
  make_fixture

  run_sk
  expect_rc 3 "no keyword" || ok=1
  assert_output_contains "$SK_OUT" "error=no keyword given" || ok=1
  assert_file_contains "$SK_ERR" "Usage:" || ok=1

  run_sk ""
  expect_rc 3 "empty keyword" || ok=1
  assert_output_contains "$SK_OUT" "error=empty keyword" || ok=1

  run_sk "two
lines"
  expect_rc 3 "keyword with a newline" || ok=1
  assert_output_contains "$SK_OUT" "error=a keyword must be one line" || ok=1

  run_sk --bogus foo
  expect_rc 3 "unknown option" || ok=1
  assert_output_contains "$SK_OUT" "error=unknown option: --bogus" || ok=1

  run_sk --max-files x foo
  expect_rc 3 "--max-files x" || ok=1
  run_sk --max-lines "" foo
  expect_rc 3 "--max-lines ''" || ok=1
  run_sk foo --knowledge
  expect_rc 3 "--knowledge without a value" || ok=1
  assert_output_not_contains "$SK_OUT" "[K]" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 13: one search procedure for every caller ---

test_call_sites() {
  local test_name="search: every step that asks 'is it already written' calls the script"
  setup_test_env "$test_name"
  local ok=0 f

  # The four places named when the script was introduced, plus the two other
  # steps that ask the same question.
  for f in \
    "$FW/agents/kaizen-learning-reflector.md" \
    "$FW/agents/kaizen-learning-verifier.md" \
    "$FW/commands/kaizen-update-docs.md" \
    "$FW/commands/kaizen-suggest-next.md" \
    "$FW/agents/kaizen-learning-auditor.md" \
    "$FW/skills/kaizen-editing-knowledge/SKILL.md"; do
    assert_file_contains "$f" 'bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-search-knowledge.sh"' \
      "${f#"$FW"/} should call kaizen-search-knowledge.sh" || ok=1
    # ... and points at the one place that says how to read a 0.
    assert_file_contains "$f" '`.claude/skills/kaizen-reflect-learning/CRITERIA.md § knowledge/ の検索方法`' \
      "${f#"$FW"/} should refer to the search section of CRITERIA.md" || ok=1
  done
  if ! bash "$BIN/kaizen-extract-section.sh" "$FW/skills/kaizen-reflect-learning/CRITERIA.md" \
       'knowledge/ の検索方法' > /dev/null 2>&1; then
    echo "  FAIL: CRITERIA.md has no section 'knowledge/ の検索方法' (the callers refer to it)"
    ok=1
  fi

  # The criteria explain the command and what a 0 can mean besides absence.
  local criteria="$FW/skills/kaizen-reflect-learning/CRITERIA.md"
  assert_file_contains "$criteria" 'bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-search-knowledge.sh"' || ok=1
  local mode
  while IFS= read -r mode; do
    assert_file_contains "$criteria" "$mode" "CRITERIA.md should list the failure mode: $mode" || ok=1
  done <<'EOF'
**symlink の取りこぼし**
**走査範囲の不足**
**表記揺れ**
**実装形式を仮定した検索語**
**探索ファイルの絞りすぎ**
**Markdown の装飾が語の途中に入る**
**`head -N` による打ち切り**
**検索コマンド自体の失敗**
EOF

  # No caller keeps its own recipe for the same search.
  local hits
  hits="$(grep -rnF -e '"$(readlink -f knowledge)/"' -e '"$(readlink -f knowledge)" --exclude-dir' "$FW" || true)"
  if [ -n "$hits" ]; then
    echo "  FAIL: a hand-written search of the knowledge directory remains:"
    printf '%s\n' "$hits" | sed 's/^/    /'
    ok=1
  fi
  hits="$(grep -nF 'grep -rln' "$FW/commands/kaizen-suggest-next.md" || true)"
  if [ -n "$hits" ]; then
    echo "  FAIL: kaizen-suggest-next.md still carries its own grep: $hits"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== kaizen-search-knowledge.sh tests ==="
echo ""

test_basic
test_projects_excluded
test_fixed_string
test_keywords_and_zero
test_limits
test_clip
test_uncommitted
test_also
test_partial
test_unreadable_file
test_broken_grep
test_usage_errors
test_call_sites

print_results
