#!/bin/bash
# Tests for framework/bin/kaizen-knowledge-commit.sh
# Usage: bash tests/test_knowledge_commit.sh
#
# Runs in isolated temp directories — does not affect the real environment.
# The reference gate needs python3 (optional dependency): the gate cases are
# skipped without it, the commit cases are not.

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

KC="$KAIZEN_CLI_DIR/framework/bin/kaizen-knowledge-commit.sh"

# Keep the developer's git configuration (signing, hooks path, templates) out.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

HAVE_PYTHON=0
if command -v python3 >/dev/null 2>&1; then HAVE_PYTHON=1; fi

# --- Helpers ---

# run_kc <cwd> <args...> — sets KC_OUT (stdout + stderr) and KC_RC
run_kc() {
  local dir="$1"
  shift
  KC_RC=0
  KC_OUT=$(cd "$dir" && bash "$KC" "$@" 2>&1) || KC_RC=$?
}

assert_rc() {
  local expected="$1"
  if [ "$KC_RC" -ne "$expected" ]; then
    echo "  FAIL: exit code should be $expected, got $KC_RC"
    echo "$KC_OUT" | sed 's/^/    | /'
    return 1
  fi
}

has() { assert_output_contains "$KC_OUT" "$1" "${2:-output should contain '$1'}"; }
hasnt() { assert_output_not_contains "$KC_OUT" "$1" "${2:-output should not contain '$1'}"; }

commits() { git -C "$KN" rev-list --count HEAD; }
head_files() { git -C "$KN" show --name-status --format= HEAD; }

assert_eq() {
  if [ "$1" != "$2" ]; then
    echo "  FAIL: ${3:-values differ}"
    echo "    expected: $2"
    echo "    actual:   $1"
    return 1
  fi
}

# A knowledge repository whose registry (default/) is a subdirectory, and a
# project whose knowledge/ links to that registry — the layout setup.sh makes.
setup_repo() {
  setup_test_env "$1"
  KN="$TEST_HOME/kn"
  REG="$KN/default"
  P="$TEST_HOME/proj"
  mkdir -p "$REG/meta" "$REG/aws" "$REG/projects/details" "$P/docs"
  cat > "$REG/meta/GUIDE.md" <<'EOF'
# Guide

## Alpha

Old line with a broken reference that predates this commit: `aws/S3.md § Gone`.
EOF
  cat > "$REG/aws/S3.md" <<'EOF'
# S3

## Listing

Paginate.
EOF
  echo "# Other" > "$REG/aws/OTHER.md"
  echo "# Mirror" > "$REG/projects/details/demo.md"
  git -C "$KN" init -q
  git -C "$KN" config commit.gpgsign false
  git -C "$KN" add -A
  git -C "$KN" commit -q -m "init"
  ln -s "$REG" "$P/knowledge"
  KN_PHYS="$(cd "$KN" && pwd -P)"
}

# --- Test 1: only the given paths are committed ---

test_commits_only_given_paths() {
  local test_name="commit: only the given paths; other sessions' changes stay"
  setup_repo "$test_name"
  local ok=0

  echo "mine" >> "$REG/aws/S3.md"
  echo "foreign unstaged" >> "$REG/aws/OTHER.md"
  echo "foreign staged" > "$REG/aws/STAGED.md"
  git -C "$KN" add default/aws/STAGED.md
  echo "foreign untracked" > "$REG/aws/UNTRACKED.md"

  run_kc "$P" -m "kaizen reflect: note pagination" -m "Second paragraph." -- knowledge/aws/S3.md
  assert_rc 0 || ok=1
  has "status=committed" || ok=1
  has "repo=$KN_PHYS" || ok=1
  has "other_changes=3" "the three foreign changes are counted" || ok=1
  has "other:  M default/aws/OTHER.md" || ok=1
  has "other: A  default/aws/STAGED.md" || ok=1
  has "other: ?? default/aws/UNTRACKED.md" || ok=1
  has "message: kaizen reflect: note pagination" || ok=1
  has "message: Second paragraph." || ok=1
  has "remaining=3" || ok=1

  assert_eq "$(commits)" "2" "exactly one new commit" || ok=1
  assert_eq "$(head_files)" "M	default/aws/S3.md" "the commit holds the given file only" || ok=1
  assert_eq "$(git -C "$KN" log -1 --format=%s)" "kaizen reflect: note pagination" "subject is recorded as given" || ok=1
  # The foreign changes are exactly where they were: staged stays staged.
  assert_eq "$(git -C "$KN" status --short | sort)" "$(printf ' M default/aws/OTHER.md\n?? default/aws/UNTRACKED.md\nA  default/aws/STAGED.md' | sort)" \
    "foreign changes are untouched" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: how paths and the knowledge directory are given ---

test_path_forms() {
  local test_name="paths: through the symlink, absolute, --knowledge from elsewhere, unborn branch"
  setup_repo "$test_name"
  local ok=0

  echo "a" >> "$REG/aws/S3.md"
  run_kc "$P" -m "kaizen: relative through the link" -- ./knowledge/aws/S3.md
  assert_rc 0 || ok=1
  assert_eq "$(head_files)" "M	default/aws/S3.md" "relative path through knowledge/" || ok=1

  echo "b" >> "$REG/aws/S3.md"
  run_kc "$P" -m "kaizen: absolute" -- "$REG/aws/S3.md"
  assert_rc 0 || ok=1
  assert_eq "$(commits)" "3" "absolute path is accepted" || ok=1

  echo "c" >> "$REG/aws/S3.md"
  run_kc "$TEST_HOME" -m "kaizen: from elsewhere" --knowledge "$REG" -- "$REG/aws/S3.md"
  assert_rc 0 || ok=1
  assert_eq "$(commits)" "4" "--knowledge works without a knowledge/ in the cwd" || ok=1

  run_kc "$TEST_HOME" -m "kaizen: no knowledge here" -- "$REG/aws/S3.md"
  assert_rc 3 || ok=1
  has "no knowledge/ in the current directory" || ok=1

  # A repository without any commit yet (the first commit of setup.sh failed).
  mkdir -p "$TEST_HOME/fresh/meta"
  git -C "$TEST_HOME/fresh" init -q
  git -C "$TEST_HOME/fresh" config commit.gpgsign false
  echo "# First" > "$TEST_HOME/fresh/meta/FIRST.md"
  echo "# Not mine" > "$TEST_HOME/fresh/meta/NOT_MINE.md"
  run_kc "$TEST_HOME" -m "kaizen: first" --knowledge "$TEST_HOME/fresh" -- "$TEST_HOME/fresh/meta/FIRST.md"
  assert_rc 0 || ok=1
  has "status=committed" || ok=1
  assert_eq "$(git -C "$TEST_HOME/fresh" show --name-status --format= HEAD)" "A	meta/FIRST.md" \
    "first commit holds the given file only" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: not a git repository ---

test_not_a_git_repository() {
  local test_name="non-git: nothing happens, exit 0"
  setup_test_env "$test_name"
  local ok=0

  mkdir -p "$TEST_HOME/plain/meta"
  echo "# Guide" > "$TEST_HOME/plain/meta/GUIDE.md"
  KC_RC=0
  KC_OUT=$(cd "$TEST_HOME" && GIT_CEILING_DIRECTORIES="$TEST_HOME" bash "$KC" -m "kaizen: x" \
    --knowledge "$TEST_HOME/plain" -- "$TEST_HOME/plain/meta/GUIDE.md" 2>&1) || KC_RC=$?
  assert_rc 0 || ok=1
  has "status=skipped" || ok=1
  has "reason=not a git repository" || ok=1
  assert_file_contains "$TEST_HOME/plain/meta/GUIDE.md" "# Guide" "the file is untouched" || ok=1
  if [ -e "$TEST_HOME/plain/.git" ]; then
    echo "  FAIL: no repository should be created"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: removed and missing paths ---

test_removed_and_missing_paths() {
  local test_name="removed paths: a deletion is committed, a missing path does not abort the rest"
  setup_repo "$test_name"
  local ok=0

  # One valid edit, one tracked file removed, one path that never existed.
  echo "mine" >> "$REG/aws/S3.md"
  rm "$REG/aws/OTHER.md"
  run_kc "$P" -m "kaizen audit: drop other" -- knowledge/aws/NEVER.md knowledge/aws/S3.md knowledge/aws/OTHER.md
  assert_rc 0 || ok=1
  has "status=committed" || ok=1
  has "skipped: knowledge/aws/NEVER.md (no such file, and not tracked)" || ok=1
  assert_eq "$(head_files | sort)" "$(printf 'D\tdefault/aws/OTHER.md\nM\tdefault/aws/S3.md')" \
    "the edit and the deletion are in one commit" || ok=1
  has "remaining=0" || ok=1

  # A rename: old and new path together.
  mv "$REG/aws/S3.md" "$REG/aws/S3_LISTING.md"
  run_kc "$P" -m "kaizen: rename" -- knowledge/aws/S3.md knowledge/aws/S3_LISTING.md
  assert_rc 0 || ok=1
  assert_eq "$(git -C "$KN" show --name-status -M --format= HEAD | cut -f2-)" "default/aws/S3.md	default/aws/S3_LISTING.md" \
    "both sides of the rename are committed" || ok=1

  # Removed with `git rm`, moved with `git mv`: already out of the index, so
  # `git add` cannot take them — the commit still has to.
  git -C "$KN" rm -q default/projects/details/demo.md
  git -C "$KN" mv default/aws/S3_LISTING.md default/aws/S3_PAGES.md
  run_kc "$P" -m "kaizen: git rm and git mv" -- knowledge/projects/details/demo.md \
    knowledge/aws/S3_LISTING.md knowledge/aws/S3_PAGES.md
  assert_rc 0 || ok=1
  has "status=committed" || ok=1
  hasnt "skipped:" "a path removed with git rm is not skipped" || ok=1
  assert_eq "$(git -C "$KN" show --name-status -M --format= HEAD | sort)" \
    "$(printf 'D\tdefault/projects/details/demo.md\nR100\tdefault/aws/S3_LISTING.md\tdefault/aws/S3_PAGES.md')" \
    "the staged removal and the staged rename are committed" || ok=1
  has "remaining=0" || ok=1

  # Nothing left that exists or is tracked.
  local before
  before="$(commits)"
  run_kc "$P" -m "kaizen: nothing" -- knowledge/aws/NEVER.md knowledge/gone/ALSO_NEVER.md
  assert_rc 0 || ok=1
  has "status=nothing" || ok=1
  has "reason=none of the given paths exists or is tracked" || ok=1
  assert_eq "$(commits)" "$before" "no commit is made" || ok=1

  # A removed directory is not a path to pass — whether removed with rm or git rm.
  rm -r "$REG/aws"
  run_kc "$P" -m "kaizen: dir" -- knowledge/aws
  assert_rc 3 || ok=1
  has "was a directory: knowledge/aws" || ok=1
  assert_eq "$(git -C "$KN" diff --cached --name-only)" "" "nothing is staged after a refusal" || ok=1
  # ... or staged and removed before it was ever committed (known to the index only).
  mkdir -p "$REG/newdir"
  echo "# n" > "$REG/newdir/N.md"
  git -C "$KN" add default/newdir/N.md
  rm -r "$REG/newdir"
  run_kc "$P" -m "kaizen: dir" -- knowledge/newdir
  assert_rc 3 || ok=1
  has "was a directory: knowledge/newdir" || ok=1
  git -C "$KN" rm -q --cached default/newdir/N.md

  touch "$REG/.keep"   # git rm removes emptied parents; keep the registry directory itself
  git -C "$KN" rm -r -q default/meta
  run_kc "$P" -m "kaizen: dir" -- knowledge/meta
  assert_rc 3 || ok=1
  has "was a directory: knowledge/meta" || ok=1
  assert_eq "$(commits)" "$before" "no commit is made" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 5: git failures ---

test_git_failures() {
  local test_name="git failure: reported with exit 2, the knowledge file keeps its content"
  setup_repo "$test_name"
  local ok=0

  # The commit itself fails (a hook rejects it).
  mkdir -p "$KN/.git/hooks"
  printf '#!/bin/sh\necho "rejected by hook" >&2\nexit 1\n' > "$KN/.git/hooks/pre-commit"
  chmod +x "$KN/.git/hooks/pre-commit"
  echo "kept line" >> "$REG/aws/S3.md"
  run_kc "$P" -m "kaizen reflect: will fail" -- knowledge/aws/S3.md
  assert_rc 2 || ok=1
  has "status=error" || ok=1
  has "error=git commit failed" || ok=1
  has "git: rejected by hook" "git's own message is shown" || ok=1
  assert_eq "$(commits)" "1" "no commit" || ok=1
  assert_file_contains "$REG/aws/S3.md" "kept line" "the edit is still in the file" || ok=1
  rm "$KN/.git/hooks/pre-commit"

  # git add fails for one path (ignored file): no partial commit.
  echo "IGNORED.md" > "$KN/.gitignore"
  git -C "$KN" add .gitignore
  git -C "$KN" commit -q -m "ignore"
  echo "x" > "$REG/aws/IGNORED.md"
  run_kc "$P" -m "kaizen reflect: partial" -- knowledge/aws/S3.md knowledge/aws/IGNORED.md
  assert_rc 2 || ok=1
  has "failed: default/aws/IGNORED.md" || ok=1
  has "error=git add failed" || ok=1
  assert_eq "$(commits)" "2" "nothing is committed when a path cannot be staged" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: refusals before anything is staged ---

test_refusals() {
  local test_name="refusals: outside the knowledge directory, directories, bad arguments"
  setup_repo "$test_name"
  local ok=0

  # The project is a repository too: a project file must never be committed from here.
  git -C "$P" init -q
  echo "# Plan" > "$P/docs/PLAN.md"
  echo "mine" >> "$REG/aws/S3.md"

  run_kc "$P" -m "kaizen: x" -- docs/PLAN.md knowledge/aws/S3.md
  assert_rc 3 || ok=1
  has "outside the knowledge directory: docs/PLAN.md" || ok=1
  assert_eq "$(git -C "$P" status --short docs)" "?? docs/" "the project repository is untouched" || ok=1
  assert_eq "$(git -C "$KN" diff --cached --name-only)" "" "the valid path is not staged either" || ok=1

  # Leaving the knowledge directory with .. is caught after resolution.
  run_kc "$P" -m "kaizen: x" -- knowledge/../docs/PLAN.md
  assert_rc 3 || ok=1
  has "outside the knowledge directory" || ok=1

  # .. behind a directory that does not exist cannot be resolved, so it is refused
  # (as text it would still start with the knowledge directory).
  run_kc "$P" -m "kaizen: x" -- knowledge/gone/../../../proj/docs/PLAN.md
  assert_rc 3 || ok=1
  has "cannot resolve the path: knowledge/gone/../../../proj/docs/PLAN.md" || ok=1

  # Another registry of the same repository is outside this knowledge directory.
  mkdir -p "$KN/work/meta"
  echo "# W" > "$KN/work/meta/W.md"
  run_kc "$P" -m "kaizen: x" -- "$KN/work/meta/W.md"
  assert_rc 3 || ok=1

  run_kc "$P" -m "kaizen: x" -- knowledge/aws
  assert_rc 3 || ok=1
  has "is a directory: knowledge/aws" || ok=1

  run_kc "$P" -m "kaizen: x" -- knowledge
  assert_rc 3 || ok=1
  has "is the knowledge directory itself" || ok=1

  run_kc "$P" -m "kaizen: x" --knowledge "$KN" -- "$KN/.git/config"
  assert_rc 3 || ok=1
  has "inside .git" || ok=1

  run_kc "$P" -m "kaizen: x"
  assert_rc 3 || ok=1
  has "no path given" || ok=1

  run_kc "$P" -- knowledge/aws/S3.md
  assert_rc 3 || ok=1
  has "a commit message is required" || ok=1

  run_kc "$P" -m "   " -- knowledge/aws/S3.md
  assert_rc 3 || ok=1
  has "the commit message is empty" || ok=1

  run_kc "$P" -m "kaizen: x" -A -- knowledge/aws/S3.md
  assert_rc 3 || ok=1
  has "unknown argument: -A" || ok=1

  # A path before -- is not silently taken as a path.
  run_kc "$P" -m "kaizen: x" knowledge/aws/S3.md
  assert_rc 3 || ok=1

  assert_eq "$(commits)" "1" "no refusal makes a commit" || ok=1
  assert_eq "$(git -C "$KN" diff --cached --name-only)" "" "no refusal stages anything" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: nothing to commit ---

test_nothing_to_commit() {
  local test_name="nothing: an unchanged file makes no commit, exit 0"
  setup_repo "$test_name"
  local ok=0

  echo "foreign" >> "$REG/aws/OTHER.md"
  run_kc "$P" -m "kaizen sync: nothing changed" -- knowledge/aws/S3.md
  assert_rc 0 || ok=1
  has "status=nothing" || ok=1
  has "reason=no changes in the given paths" || ok=1
  has "other_changes=1" "the foreign change is still shown" || ok=1
  assert_eq "$(commits)" "1" "no commit" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 8: file names are taken literally ---

test_literal_paths() {
  local test_name="literal paths: glob characters, spaces, non-ASCII names"
  setup_repo "$test_name"
  local ok=0

  echo "# w" > "$REG/aws/weird.md"
  echo "# w" > "$REG/aws/we[i]rd.md"
  git -C "$KN" add -A
  git -C "$KN" commit -q -m "two names"
  echo "mine" >> "$REG/aws/we[i]rd.md"
  echo "foreign" >> "$REG/aws/weird.md"
  echo "# 日本語" > "$REG/aws/設計 メモ.md"

  run_kc "$P" -m "kaizen: literal" -- "knowledge/aws/we[i]rd.md" "knowledge/aws/設計 メモ.md"
  assert_rc 0 || ok=1
  has "status=committed" || ok=1
  assert_eq "$(git -C "$KN" -c core.quotepath=false show --name-only --format= HEAD | sort)" \
    "$(printf 'default/aws/we[i]rd.md\ndefault/aws/設計 メモ.md' | sort)" \
    "the bracket name is not expanded to its neighbour" || ok=1
  assert_eq "$(git -C "$KN" status --short)" " M default/aws/weird.md" "the neighbour stays uncommitted" || ok=1
  has "other:  M default/aws/weird.md" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 9: the reference gate blocks what this commit breaks ---

test_gate_blocks() {
  local test_name="gate: a broken reference in the committed lines blocks; older ones do not"
  setup_repo "$test_name"
  local ok=0
  if [ "$HAVE_PYTHON" -eq 0 ]; then
    echo "  (skipped: python3 not available)"
    record_result "$test_name" 0
    teardown_test_env
    return
  fi

  # The file already carries a broken reference (line 5). A sound addition passes.
  printf '\nSee [listing](../aws/S3.md#listing) and `aws/S3.md § Listing`.\n' >> "$REG/meta/GUIDE.md"
  run_kc "$P" -m "kaizen reflect: sound" -- knowledge/meta/GUIDE.md
  assert_rc 0 || ok=1
  has "gate=passed" || ok=1
  has "gate_detail=total: checked 1 file(s) / OK 2 / MISS 0" || ok=1

  # A broken addition blocks, and names the line.
  printf '\nSee [gone](./GONE.md), [anchor](../aws/S3.md#nope), [here](#nowhere), `aws/S3.md § Missing`.\n' >> "$REG/meta/GUIDE.md"
  local before
  before="$(commits)"
  run_kc "$P" -m "kaizen reflect: broken" -- knowledge/meta/GUIDE.md
  assert_rc 1 || ok=1
  has "status=blocked" || ok=1
  has "gate=blocked" || ok=1
  has 'MISS meta/GUIDE.md:9  `./GONE.md` (link target not found)' || ok=1
  has 'MISS meta/GUIDE.md:9  `../aws/S3.md#nope` (no matching heading)' || ok=1
  has 'MISS meta/GUIDE.md:9  `#nowhere` (no matching heading)' || ok=1
  has 'MISS meta/GUIDE.md:9  `aws/S3.md § Missing` (no matching heading)' || ok=1
  hasnt "§ Gone" "the older broken reference is not this commit's" || ok=1
  assert_eq "$(commits)" "$before" "nothing is committed" || ok=1
  assert_eq "$(git -C "$KN" diff --cached --name-only)" "default/meta/GUIDE.md" "the path stays staged" || ok=1

  # Fixing the line and running the same command again commits.
  sed '$d' "$REG/meta/GUIDE.md" > "$REG/meta/GUIDE.md.tmp" && mv "$REG/meta/GUIDE.md.tmp" "$REG/meta/GUIDE.md"
  printf 'See [alpha](#alpha).\n' >> "$REG/meta/GUIDE.md"
  run_kc "$P" -m "kaizen reflect: fixed" -- knowledge/meta/GUIDE.md
  assert_rc 0 || ok=1
  has "status=committed" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 10: what the gate leaves alone ---

test_gate_scope() {
  local test_name="gate: other sessions' staged files, registry mirrors, and the bypass"
  setup_repo "$test_name"
  local ok=0
  if [ "$HAVE_PYTHON" -eq 0 ]; then
    echo "  (skipped: python3 not available)"
    record_result "$test_name" 0
    teardown_test_env
    return
  fi

  # Another session staged a file with a broken reference. Not ours to judge.
  printf '\n[bad](./NOPE.md)\n' >> "$REG/aws/OTHER.md"
  git -C "$KN" add default/aws/OTHER.md
  echo "mine" >> "$REG/aws/S3.md"
  run_kc "$P" -m "kaizen reflect: mine" -- knowledge/aws/S3.md
  assert_rc 0 || ok=1
  has "gate=passed" || ok=1
  assert_eq "$(head_files)" "M	default/aws/S3.md" "only the given file is committed" || ok=1

  # A registry mirror is a copy of a project file: its references point into
  # that project and are not checked here.
  printf '\nSee `docs/PLAN.md § Phase 1` and [x](./NOT_IN_REGISTRY.md).\n' >> "$REG/projects/details/demo.md"
  run_kc "$P" -m "kaizen sync: update project registry for demo" -- knowledge/projects/details/demo.md
  assert_rc 0 || ok=1
  has "status=committed" || ok=1
  has "gate_detail=--staged: nothing was checked" || ok=1

  # The bypass, for a reference written on purpose.
  printf '\n[bad](./NOPE.md)\n' >> "$REG/meta/GUIDE.md"
  run_kc "$P" -m "kaizen reflect: on purpose" --allow-broken-refs -- knowledge/meta/GUIDE.md
  assert_rc 0 || ok=1
  has "gate=bypassed (--allow-broken-refs)" || ok=1
  has "status=committed" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 11: without python3 the gate is skipped, not silently passed ---

test_gate_without_python() {
  local test_name="gate: without python3 the commit goes through and says the gate was skipped"
  setup_repo "$test_name"
  local ok=0

  # A PATH that has everything the script calls except python3.
  local shim="$TEST_HOME/shim" c
  mkdir -p "$shim"
  for c in dirname git wc tr head sed grep tail; do
    ln -s "$(command -v "$c")" "$shim/$c"
  done
  printf '\n[bad](./NOPE.md)\n' >> "$REG/meta/GUIDE.md"
  local bash_bin
  bash_bin="$(command -v bash)"
  KC_RC=0
  KC_OUT=$(cd "$P" && PATH="$shim" "$bash_bin" "$KC" -m "kaizen reflect: no python" -- knowledge/meta/GUIDE.md 2>&1) || KC_RC=$?
  assert_rc 0 || ok=1
  has "gate=skipped (python3 not found)" || ok=1
  has "status=committed" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== kaizen-knowledge-commit.sh tests ==="
echo ""

test_commits_only_given_paths
test_path_forms
test_not_a_git_repository
test_removed_and_missing_paths
test_git_failures
test_refusals
test_nothing_to_commit
test_literal_paths
test_gate_blocks
test_gate_scope
test_gate_without_python

print_results
