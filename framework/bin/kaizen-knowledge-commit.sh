#!/bin/bash
# kaizen-knowledge-commit.sh — Commit the given files of the knowledge repository, and only those.
#
# Usage:
#   kaizen-knowledge-commit.sh -m <message> [--knowledge <dir>] [--allow-broken-refs] -- <path>...
#
#   -m <message>         Commit message. Repeat for more paragraphs (as in git).
#   --knowledge <dir>    Knowledge directory (the registry that the project's
#                        knowledge/ link points to). Default: ./knowledge
#   --allow-broken-refs  Commit even if the reference gate finds a broken
#                        reference in the lines being committed. For a
#                        reference that is written on purpose; ask the user first.
#   <path>...            The files you edited, created, or removed. Relative to
#                        the current directory (knowledge/aws/S3.md works from
#                        a project) or absolute. Files only — not directories.
#
# Why a script instead of `git add -A && git commit`: the knowledge directory
# is shared by every project and every session. `add -A` stages whatever
# another session left unfinished, and a commit without paths takes everything
# in the index — including what another session staged. Both put changes into
# the history that the commit message does not mention.
#
# What it does:
#   1. Resolves each path through the knowledge/ symlink and refuses a path
#      outside the knowledge directory (nothing is staged in that case).
#   2. Lists the other uncommitted changes of the repository. They are shown
#      so that another session's work is visible; they are not touched.
#   3. Stages the given paths one by one. A path that does not exist and is not
#      tracked is skipped with a note — in one `git add` call it would abort
#      the whole call and leave the valid paths unstaged too. A path already
#      removed with `git rm` or `git mv` is not passed to `git add` (same
#      abort) but is part of the commit.
#   4. Runs the reference gate (kaizen-check-refs.py --corpus --staged) on the
#      lines being committed. Existing broken references elsewhere do not
#      block. Needs python3; without it the gate is skipped and says so.
#   5. Commits with `git commit -- <paths>`, never without paths.
#   6. Prints the commit message as recorded, the files of the commit, and
#      what is still uncommitted.
#
# Output: a [kaizen-knowledge-commit] block of key=value and `label: text`
# lines. The gate's own output follows the block when it found something.
#
# Exit codes:
#   0 = committed / nothing to commit in the given paths / not a git repository
#       (status=committed | nothing | skipped)
#   1 = blocked by the reference gate; nothing was committed, the paths stay staged
#   2 = git failed (add or commit); the knowledge files themselves are untouched
#   3 = usage error, or a path that cannot be committed from here (outside the
#       knowledge directory, a directory); nothing was staged

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_REFS="$SCRIPT_DIR/kaizen-check-refs.py"
TAG="kaizen-knowledge-commit"
LIST_LIMIT=20

usage() {
  echo "Usage: kaizen-knowledge-commit.sh -m <message> [--knowledge <dir>] [--allow-broken-refs] -- <path>..." >&2
}

# finish <status> <exit code> — closes the block and exits.
finish() {
  echo "status=$1"
  echo "[/$TAG]"
  if [ -n "${GATE_TEXT:-}" ]; then
    echo ""
    printf '%s\n' "$GATE_TEXT"
  fi
  exit "$2"
}

# die <message> — usage-level failure before anything was staged.
die() {
  echo "[$TAG]"
  echo "error=$1"
  finish error 3
}

# physical_path <path> — absolute path with every existing directory resolved
# (symlinks followed). The path itself does not have to exist: a removed file
# is a valid thing to commit.
physical_path() {
  local p="$1" dir rest="" base
  case "$p" in
    /*) ;;
    *) p="$PWD/$p" ;;
  esac
  while [ "$p" != "/" ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
  dir="$p"
  while [ ! -d "$dir" ]; do
    base="${dir##*/}"
    rest="/$base$rest"
    dir="${dir%/*}"
    [ -z "$dir" ] && dir="/"
  done
  case "$rest/" in
    */../*|*/./*) return 1 ;;
  esac
  dir="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
  [ "$dir" = "/" ] && dir=""
  printf '%s%s\n' "$dir" "$rest"
}

# print_list <label> <text> — one `label: line` per line, capped at LIST_LIMIT.
print_list() {
  local label="$1" text="$2" total
  [ -z "$text" ] && return 0
  total=$(printf '%s\n' "$text" | wc -l | tr -d ' ')
  printf '%s\n' "$text" | head -n "$LIST_LIMIT" | sed "s/^/$label: /"
  if [ "$total" -gt "$LIST_LIMIT" ]; then
    echo "$label: ... ($((total - LIST_LIMIT)) more)"
  fi
}

# --- Arguments ---

MESSAGES=()
KNOWLEDGE_ARG=""
ALLOW_BROKEN=0
PATHS=()
GATE_TEXT=""

while [ $# -gt 0 ]; do
  case "$1" in
    -m)
      [ $# -ge 2 ] || { usage; die "-m needs a message"; }
      MESSAGES+=("$2"); shift 2 ;;
    --knowledge)
      [ $# -ge 2 ] || { usage; die "--knowledge needs a directory"; }
      KNOWLEDGE_ARG="$2"; shift 2 ;;
    --allow-broken-refs) ALLOW_BROKEN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) usage; die "unknown argument: $1 (paths go after --)" ;;
  esac
done
while [ $# -gt 0 ]; do PATHS+=("$1"); shift; done

if [ ${#MESSAGES[@]} -eq 0 ]; then usage; die "a commit message is required (-m)"; fi
if [ -z "$(printf '%s' "${MESSAGES[0]}" | tr -d '[:space:]')" ]; then die "the commit message is empty"; fi
if [ ${#PATHS[@]} -eq 0 ]; then
  usage
  die "no path given: list the files you changed after -- (this script never commits everything)"
fi

KROOT="${KNOWLEDGE_ARG:-knowledge}"
if [ ! -d "$KROOT" ]; then
  if [ -n "$KNOWLEDGE_ARG" ]; then
    die "knowledge directory does not exist: $KNOWLEDGE_ARG"
  fi
  die "no knowledge/ in the current directory: run from the project root or pass --knowledge <dir>"
fi
KROOT="$(cd "$KROOT" && pwd -P)" || die "cannot enter the knowledge directory"

# --- Is it a git repository? ---

if ! command -v git >/dev/null 2>&1; then
  echo "[$TAG]"
  echo "knowledge_dir=$KROOT"
  echo "reason=git not found"
  finish skipped 0
fi
TOP="$(git -C "$KROOT" rev-parse --show-toplevel 2>/dev/null)" || TOP=""
if [ -z "$TOP" ]; then
  echo "[$TAG]"
  echo "knowledge_dir=$KROOT"
  echo "reason=not a git repository"
  finish skipped 0
fi
TOP="$(cd "$TOP" && pwd -P)" || die "cannot enter the repository: $TOP"

# --- Resolve and classify the paths (nothing is staged before this passes) ---

RELS=()       # repository-relative paths to commit
ADDS=()       # those among them that `git add` has to stage
MD_ABS=()     # existing *.md among them, for the reference gate
SKIPPED=""
for p in "${PATHS[@]}"; do
  [ -n "$p" ] || die "empty path"
  phys="$(physical_path "$p")" || die "cannot resolve the path: $p"
  case "$phys/" in
    "$KROOT"/*) ;;
    *) die "outside the knowledge directory: $p (resolved to $phys; knowledge directory: $KROOT)" ;;
  esac
  [ "$phys" = "$KROOT" ] && die "is the knowledge directory itself: $p — pass the files you changed"
  rel="${phys#"$TOP"/}"
  case "/$rel/" in
    */.git/*) die "inside .git: $p" ;;
  esac
  if [ -d "$phys" ] && [ ! -L "$phys" ]; then
    die "is a directory: $p — pass the files you changed (a directory would take other sessions' changes with it)"
  fi
  if [ ! -e "$phys" ] && [ ! -L "$phys" ]; then
    # Gone from the working tree. Three cases: removed with `rm` (still in the
    # index: `git add` stages the removal), removed with `git rm` / `git mv`
    # (gone from the index too: `git add` would abort, the commit takes it),
    # or never known to git (skipped).
    tracked="$(git -C "$TOP" --literal-pathspecs ls-files -- "$rel" 2>/dev/null)"
    if [ "$tracked" = "$rel" ]; then
      ADDS+=("$rel")
    elif [ -n "$tracked" ]; then
      die "was a directory: $p — pass the removed files one by one"
    else
      in_head="$(git -C "$TOP" cat-file -t "HEAD:$rel" 2>/dev/null)" || in_head=""
      if [ "$in_head" = "tree" ]; then
        die "was a directory: $p — pass the removed files one by one"
      elif [ "$in_head" != "blob" ]; then
        SKIPPED="${SKIPPED}${p} (no such file, and not tracked)"$'\n'
        continue
      fi
    fi
  else
    ADDS+=("$rel")
    case "$rel" in
      *.md) MD_ABS+=("$TOP/$rel") ;;
    esac
  fi
  RELS+=("$rel")
done
SKIPPED="${SKIPPED%$'\n'}"

echo "[$TAG]"
echo "knowledge_dir=$KROOT"
echo "repo=$TOP"
print_list "skipped" "$SKIPPED"

if [ ${#RELS[@]} -eq 0 ]; then
  echo "reason=none of the given paths exists or is tracked"
  finish nothing 0
fi

# --- Other uncommitted changes: shown, never touched ---

EXCLUDES=()
for rel in "${RELS[@]}"; do EXCLUDES+=(":(exclude,literal)$rel"); done
OTHER="$(git -C "$TOP" status --short --untracked-files=all -- . "${EXCLUDES[@]}" 2>/dev/null)" || OTHER=""
if [ -n "$OTHER" ]; then
  echo "other_changes=$(printf '%s\n' "$OTHER" | wc -l | tr -d ' ')"
  print_list "other" "$OTHER"
else
  echo "other_changes=0"
fi

# --- Stage the given paths, one by one ---

FAILED=""
for rel in ${ADDS[@]+"${ADDS[@]}"}; do
  if ! err="$(git -C "$TOP" --literal-pathspecs add -- "$rel" 2>&1)"; then
    FAILED="${FAILED}${rel} ($(printf '%s' "$err" | head -n 1))"$'\n'
  fi
done
if [ -n "$FAILED" ]; then
  print_list "failed" "${FAILED%$'\n'}"
  echo "error=git add failed for the paths above; nothing was committed (paths staged before the failure stay staged)"
  finish error 2
fi

if git -C "$TOP" --literal-pathspecs diff --cached --quiet -- "${RELS[@]}"; then
  echo "reason=no changes in the given paths"
  finish nothing 0
fi

# --- Reference gate: only the lines about to be committed ---

GATE="passed"
if [ "$ALLOW_BROKEN" -eq 1 ]; then
  GATE="bypassed (--allow-broken-refs)"
elif [ ${#MD_ABS[@]} -eq 0 ]; then
  GATE="nothing to check (no Markdown file among the paths)"
elif ! command -v python3 >/dev/null 2>&1; then
  GATE="skipped (python3 not found)"
elif [ ! -f "$CHECK_REFS" ]; then
  GATE="skipped (kaizen-check-refs.py not found next to this script)"
else
  gate_rc=0
  gate_out="$(python3 "$CHECK_REFS" --corpus "$KROOT" --staged "${MD_ABS[@]}" 2>&1)" || gate_rc=$?
  gate_last="$(printf '%s\n' "$gate_out" | grep -E '^(total:|--staged:)' | tail -n 1)"
  has_miss=0
  if printf '%s\n' "$gate_out" | grep -q '^MISS '; then has_miss=1; fi
  if [ "$gate_rc" -eq 1 ] || { [ "$gate_rc" -eq 2 ] && [ "$has_miss" -eq 1 ]; }; then
    echo "gate=blocked"
    [ -n "$gate_last" ] && echo "gate_detail=$gate_last"
    echo "error=broken references in the lines being committed (MISS lines below); nothing was committed, the paths stay staged"
    echo "fix=correct the references and run the same command again"
    GATE_TEXT="$gate_out"
    finish blocked 1
  elif [ "$gate_rc" -eq 0 ]; then
    GATE="passed"
  elif [ "$gate_rc" -eq 2 ]; then
    GATE="incomplete (unreadable file — see the UNREAD lines below; committed anyway)"
    GATE_TEXT="$gate_out"
  else
    GATE="not run (kaizen-check-refs.py exited $gate_rc — committed without the check)"
    GATE_TEXT="$gate_out"
  fi
fi
echo "gate=$GATE"
[ -n "${gate_last:-}" ] && echo "gate_detail=$gate_last"

# --- Commit: always with paths ---

MSG_ARGS=()
for m in "${MESSAGES[@]}"; do MSG_ARGS+=(-m "$m"); done
if ! err="$(git -C "$TOP" --literal-pathspecs commit -q "${MSG_ARGS[@]}" -- "${RELS[@]}" 2>&1)"; then
  print_list "git" "$err"
  echo "error=git commit failed; the knowledge files are unchanged and the paths stay staged"
  finish error 2
fi

echo "commit=$(git -C "$TOP" rev-parse --short HEAD 2>/dev/null)"
print_list "message" "$(git -C "$TOP" log -1 --format=%B)"
print_list "committed" "$(git -C "$TOP" show --name-status --format= HEAD)"
REMAINING="$(git -C "$TOP" status --short 2>/dev/null)" || REMAINING=""
if [ -n "$REMAINING" ]; then
  echo "remaining=$(printf '%s\n' "$REMAINING" | wc -l | tr -d ' ')"
  print_list "remaining" "$REMAINING"
else
  echo "remaining=0"
fi
finish committed 0
