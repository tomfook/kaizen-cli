#!/bin/bash
# kaizen-search-knowledge.sh — Look for existing knowledge in every place it can live, with one command.
#
# Usage:
#   kaizen-search-knowledge.sh [options] [--] <keyword>...
#
#   <keyword>            Fixed string (not a regular expression). Several may be
#                        given; each is reported on its own. Pass the shortest
#                        identifying term — a phrase is split by Markdown markup
#                        (`**`, backticks) more often than a single term is.
#   --knowledge <dir>    Knowledge directory (the registry that the project's
#                        knowledge/ link points to). Default: ./knowledge
#   --also <dir>         One more directory to scan, e.g. the project's docs/.
#                        Repeatable. Symbolic links inside it are not followed,
#                        so `--also .claude` adds only the project's own files
#                        (the linked framework files are scanned at their source).
#   -i, --ignore-case    Ignore case (ASCII letters only).
#   --max-files <N>      [H] is printed for at most N files (default 10).
#   --max-lines <N>      [H] prints at most N lines per file (default 5).
#
# What is scanned:
#   knowledge/   the knowledge directory, resolved through the symlink.
#                projects/ at its top is excluded: it holds mirrors of each
#                project's own docs, so a hit there is a self-reference.
#   framework/   skills, commands, and agents of this kaizen-cli checkout
#                (framework/.claude next to this script) — a rule may already be
#                written in a skill rather than in knowledge/.
#   --also dirs  as given.
#
# Why a script instead of grep: `grep -r knowledge/` returns nothing, without an
# error, when it does not follow the symlink; a search of knowledge/ alone misses
# what a skill already says; and a failed search looks the same as no hit. This
# script walks the real paths, names what it scanned and what it could not, and
# checks first that find and grep answer at all.
#
# Output: a [kaizen-search-knowledge] block.
#   area: <label> -> <real path> (<n> files)     what was scanned
#   not-scanned: <what> (<why>)                  what was not — a 0 does not cover it
#   [K] "<keyword>": <n> file(s)                 files that contain the keyword, one per line below
#   [H] <file> (<n> line(s))                     per file: the matching lines as
#     L<line> (§ <heading>): <text>              line number, the heading of the section the line
#                                                is in (Markdown files), and the line clipped at
#                                                240 bytes. Start reading at that heading.
#   [S] ...                                      uncommitted changes of the knowledge repository
#                                                (projects/ excluded): another session may be
#                                                writing the same thing right now, and a hit in
#                                                one of these files is not in the history yet.
#   warning: <text>                              a file or directory that could not be read
#   status=ok | partial | error
#
# Paths under [K] and [H] are <label><path inside the area>: knowledge/... can be
# read from the project as is; framework/... is relative to the path on its
# `area:` line.
#
# 0 files is not proof of absence. Whether "not found" means "not written" is the
# reader's call: the term may be written differently, or split by markup.
#
# Exit codes:
#   0 = the search ran over every area (with or without hits)
#   1 = the search ran, but something was not scanned (status=partial):
#       read the not-scanned: / warning: lines before concluding anything
#   2 = the search could not run (find or grep does not answer here)
#   3 = usage error, or nothing to scan
#
# Portability: bash 3.2, POSIX find / grep / awk. The script runs in the C
# locale, so matching, sorting, and clipping work on bytes and give the same
# result everywhere; text is clipped on a UTF-8 character boundary.

set -uo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT="$SCRIPT_DIR/kaizen-extract-section.sh"
FRAMEWORK_DIR="$SCRIPT_DIR/../.claude"
TAG="kaizen-search-knowledge"
CLIP_BYTES=240
STATUS_LIMIT=20

usage() {
  cat >&2 <<'EOF'
Usage: kaizen-search-knowledge.sh [--knowledge <dir>] [--also <dir>]... [-i] [--max-files <N>] [--max-lines <N>] [--] <keyword>...
  Fixed-string search of the knowledge directory (projects/ excluded) and of the
  framework's skills, commands, and agents. 0 files is not proof of absence.
Exit codes: 0 = searched every area, 1 = something was not scanned, 2 = cannot search here, 3 = usage error
EOF
}

# die <exit code> <message> — failure before any result was printed.
die() {
  echo "[$TAG]"
  echo "error=$2"
  echo "status=error"
  echo "[/$TAG]"
  exit "$1"
}

# --- Arguments ---

KNOWLEDGE_ARG=""
ALSO=()
KEYWORDS=()
IGNORE_CASE=0
MAX_FILES=10
MAX_LINES=5

while [ $# -gt 0 ]; do
  case "$1" in
    --knowledge)
      [ $# -ge 2 ] || { usage; die 3 "--knowledge needs a directory"; }
      KNOWLEDGE_ARG="$2"; shift 2 ;;
    --also)
      [ $# -ge 2 ] || { usage; die 3 "--also needs a directory"; }
      ALSO+=("$2"); shift 2 ;;
    -i|--ignore-case) IGNORE_CASE=1; shift ;;
    --max-files)
      [ $# -ge 2 ] || { usage; die 3 "--max-files needs a number"; }
      MAX_FILES="$2"; shift 2 ;;
    --max-lines)
      [ $# -ge 2 ] || { usage; die 3 "--max-lines needs a number"; }
      MAX_LINES="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do KEYWORDS+=("$1"); shift; done ;;
    -*) usage; die 3 "unknown option: $1 (a keyword that starts with - goes after --)" ;;
    *) KEYWORDS+=("$1"); shift ;;
  esac
done

if [ ${#KEYWORDS[@]} -eq 0 ]; then usage; die 3 "no keyword given"; fi
case "$MAX_FILES" in ''|*[!0-9]*) die 3 "--max-files takes a number: $MAX_FILES" ;; esac
case "$MAX_LINES" in ''|*[!0-9]*) die 3 "--max-lines takes a number: $MAX_LINES" ;; esac
for kw in "${KEYWORDS[@]}"; do
  [ -n "$kw" ] || die 3 "empty keyword (it would match every line)"
  case "$kw" in
    *$'\n'*) die 3 "a keyword must be one line (pass each term as its own argument)" ;;
  esac
done

TMP="$(mktemp -d 2>/dev/null)" || die 2 "cannot create a temporary directory"
trap 'rm -rf "$TMP"' EXIT

# --- Does a search answer at all? ---
# A find or grep that fails prints nothing — the same as no hit. One known
# positive, through the same call that the search uses, tells the two apart.

printf 'kaizen search probe\n' > "$TMP/probe.txt"
printf 'search probe\n' > "$TMP/probe.kw"
probe="$(cd "$TMP" && find . -type f -name probe.txt -exec grep -lF -f "$TMP/probe.kw" -- {} + 2>/dev/null)" || probe=""
if [ "$probe" != "./probe.txt" ]; then
  die 2 "find/grep did not find a known string in a test file: a search here cannot tell 'no hit' from 'did not run'"
fi

if [ "$IGNORE_CASE" -eq 1 ]; then
  K_FLAGS="-liF"; H_FLAGS="-niF"
else
  K_FLAGS="-lF"; H_FLAGS="-nF"
fi

# --- Areas ---
# Parallel arrays: label (prefix of the printed paths), real root, kind.

AREA_LABEL=()
AREA_ROOT=()
AREA_KIND=()
NOT_SCANNED=""
FW_STARTS=""   # find starting points inside framework/.claude: ./skills ./commands ./agents
FW_NAMES=""    # the same, for the area: line

not_scanned() {
  NOT_SCANNED="${NOT_SCANNED}not-scanned: $1"$'\n'
}

KNOWLEDGE_ROOT=""
KDIR="${KNOWLEDGE_ARG:-knowledge}"
if [ -d "$KDIR" ] && KNOWLEDGE_ROOT="$(cd "$KDIR" 2>/dev/null && pwd -P)" && [ -n "$KNOWLEDGE_ROOT" ]; then
  AREA_LABEL+=("knowledge/"); AREA_ROOT+=("$KNOWLEDGE_ROOT"); AREA_KIND+=("knowledge")
elif [ -n "$KNOWLEDGE_ARG" ]; then
  KNOWLEDGE_ROOT=""
  not_scanned "knowledge/ (no such directory: $KNOWLEDGE_ARG)"
else
  KNOWLEDGE_ROOT=""
  not_scanned "knowledge/ (no knowledge/ in the current directory: run from the project root or pass --knowledge <dir>)"
fi

FRAMEWORK_ROOT=""
if [ -d "$FRAMEWORK_DIR" ] && FRAMEWORK_ROOT="$(cd "$FRAMEWORK_DIR" 2>/dev/null && pwd -P)" && [ -n "$FRAMEWORK_ROOT" ]; then
  for sub in skills commands agents; do
    if [ -d "$FRAMEWORK_ROOT/$sub" ]; then
      FW_STARTS="${FW_STARTS:+$FW_STARTS }./$sub"
      FW_NAMES="${FW_NAMES:+$FW_NAMES, }$sub"
    else
      not_scanned "framework/$sub (no such directory under $FRAMEWORK_ROOT)"
    fi
  done
  if [ -n "$FW_STARTS" ]; then
    AREA_LABEL+=("framework/"); AREA_ROOT+=("$FRAMEWORK_ROOT"); AREA_KIND+=("framework")
  fi
else
  not_scanned "framework/ (no such directory: $FRAMEWORK_DIR)"
fi

if [ ${#ALSO[@]} -gt 0 ]; then
  for d in "${ALSO[@]}"; do
    label="$d"
    while [ "${label%/}" != "$label" ] && [ "$label" != "/" ]; do label="${label%/}"; done
    while [ "${label#./}" != "$label" ]; do label="${label#./}"; done
    [ -n "$label" ] || label="."
    if [ -d "$d" ] && root="$(cd "$d" 2>/dev/null && pwd -P)" && [ -n "$root" ]; then
      AREA_LABEL+=("${label%/}/"); AREA_ROOT+=("$root"); AREA_KIND+=("also")
    else
      not_scanned "${label%/}/ (no such directory)"
    fi
  done
fi

if [ ${#AREA_LABEL[@]} -eq 0 ]; then
  echo "[$TAG]"
  printf '%s' "$NOT_SCANNED"
  echo "error=nothing to scan"
  echo "status=error"
  echo "[/$TAG]"
  exit 3
fi

# walk <area index> <find action...> — the regular files of one area, as ./path
# from its root. Symbolic links are not followed; .git and node_modules are
# skipped, and so is projects/ at the top of the knowledge directory.
walk() {
  local i="$1" starts="."
  shift
  [ "${AREA_KIND[$i]}" = framework ] && starts="$FW_STARTS"
  if [ "${AREA_KIND[$i]}" = knowledge ]; then
    # shellcheck disable=SC2086
    ( cd "${AREA_ROOT[$i]}" && find $starts \( -name .git -o -name node_modules -o -path ./projects \) -prune -o -type f "$@" )
  else
    # shellcheck disable=SC2086
    ( cd "${AREA_ROOT[$i]}" && find $starts \( -name .git -o -name node_modules \) -prune -o -type f "$@" )
  fi
}

# is_text <file> — no NUL byte. (`grep -I` does not do this everywhere: BusyBox
# 1.35 accepts the option and still reports a file that contains NUL.)
is_text() {
  local all text
  all=$(wc -c < "$1" 2>/dev/null) || return 1
  text=$(tr -d '\000' < "$1" 2>/dev/null | wc -c) || return 1
  [ "$((all))" -eq "$((text))" ]
}

# clip <text> — sets CLIPPED: at most CLIP_BYTES bytes, cut before a character
# start. In the C locale ${#s} and ${s:n:1} count bytes; a byte 128-191 is the
# continuation of a UTF-8 character, so the cut moves back until it is not on one.
clip() {
  local s="$1" n="$CLIP_BYTES" b tries=0
  if [ "${#s}" -le "$n" ]; then
    CLIPPED="$s"
    return 0
  fi
  while [ "$n" -gt 0 ] && [ "$tries" -lt 4 ]; do
    b=0
    printf -v b '%d' "'${s:$n:1}" 2>/dev/null || b=0
    [ "$b" -lt 0 ] && b=$((b + 256))
    if [ "$b" -ge 128 ] && [ "$b" -le 191 ]; then
      n=$((n - 1)); tries=$((tries + 1))
    else
      break
    fi
  done
  CLIPPED="${s:0:$n}…"
}

: > "$TMP/err"
: > "$TMP/union"

echo "[$TAG]"
i=0
while [ "$i" -lt ${#AREA_LABEL[@]} ]; do
  n=$(walk "$i" -print 2>>"$TMP/err" | wc -l | tr -d ' ')
  case "${AREA_KIND[$i]}" in
    knowledge) detail="$n files, projects/ excluded" ;;
    framework) detail="$n files in $FW_NAMES" ;;
    *)         detail="$n files" ;;
  esac
  echo "area: ${AREA_LABEL[$i]} -> ${AREA_ROOT[$i]} ($detail)"
  i=$((i + 1))
done
printf '%s' "$NOT_SCANNED"

# --- [K] files per keyword ---

for kw in "${KEYWORDS[@]}"; do
  printf '%s\n' "$kw" > "$TMP/kw"
  : > "$TMP/hits"
  i=0
  while [ "$i" -lt ${#AREA_LABEL[@]} ]; do
    walk "$i" -exec grep "$K_FLAGS" -f "$TMP/kw" -- {} + 2>>"$TMP/err" | sed 's|^\./||' | sort > "$TMP/area_hits"
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      is_text "${AREA_ROOT[$i]}/$rel" || continue
      printf '%s\t%s\n' "${AREA_LABEL[$i]}$rel" "${AREA_ROOT[$i]}/$rel" >> "$TMP/hits"
    done < "$TMP/area_hits"
    i=$((i + 1))
  done
  n=$(wc -l < "$TMP/hits" | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    echo "[K] \"$kw\": 0 file(s) — not proof of absence: try another wording before concluding"
  else
    echo "[K] \"$kw\": $n file(s)"
    while IFS=$'\t' read -r shown _; do
      echo "  $shown"
    done < "$TMP/hits"
    cat "$TMP/hits" >> "$TMP/union"
  fi
done

# --- [H] matching lines and the section each one is in ---

awk '!seen[$0]++' "$TMP/union" > "$TMP/files"
total=$(wc -l < "$TMP/files" | tr -d ' ')
if [ "$total" -gt "$MAX_FILES" ]; then
  echo "[H] (the first $MAX_FILES of $total files — narrow the keywords, or raise --max-files)"
fi
printf '%s\n' "${KEYWORDS[@]}" > "$TMP/allkw"
headings_noted=0
shown_files=0
while IFS=$'\t' read -r shown abs; do
  [ "$shown_files" -lt "$MAX_FILES" ] || break
  shown_files=$((shown_files + 1))
  grep "$H_FLAGS" -f "$TMP/allkw" -- "$abs" > "$TMP/lines" 2>>"$TMP/err" || :
  nlines=$(wc -l < "$TMP/lines" | tr -d ' ')
  echo "[H] $shown ($nlines line(s))"

  # Headings come from kaizen-extract-section.sh --list ("N: ## Title"), which
  # skips `#` lines inside code fences. Only Markdown has headings: in a script,
  # a `# comment` is not one.
  with_headings=0
  case "$abs" in
    *.md|*.markdown|*.mdx)
      if bash "$EXTRACT" --list "$abs" > "$TMP/heads" 2>/dev/null; then
        with_headings=1
      elif [ "$headings_noted" -eq 0 ]; then
        echo "warning: section headings are not shown (kaizen-extract-section.sh --list failed)" >> "$TMP/err"
        headings_noted=1
      fi ;;
  esac
  if [ "$with_headings" -eq 1 ]; then
    awk '
      FILENAME == ARGV[1] {
        c = index($0, ":")
        hn[++nh] = substr($0, 1, c - 1) + 0
        t = substr($0, c + 1)
        sub(/^[ \t]*#+[ \t]*/, "", t)
        ht[nh] = t
        next
      }
      {
        c = index($0, ":")
        ln = substr($0, 1, c - 1) + 0
        h = ""
        for (k = 1; k <= nh && hn[k] <= ln; k++) h = ht[k]
        print h
      }
    ' "$TMP/heads" "$TMP/lines" > "$TMP/secs"
  else
    : > "$TMP/secs"
  fi

  printed=0
  while IFS= read -r line <&3; do
    sec=""
    [ "$with_headings" -eq 1 ] && IFS= read -r sec <&4
    [ "$printed" -lt "$MAX_LINES" ] || break
    printed=$((printed + 1))
    ln="${line%%:*}"
    text="${line#*:}"
    text="${text%$'\r'}"
    text="${text#"${text%%[![:space:]]*}"}"
    clip "$text"
    if [ "$with_headings" -eq 0 ]; then
      echo "  L$ln: $CLIPPED"
    elif [ -n "$sec" ]; then
      echo "  L$ln (§ $sec): $CLIPPED"
    else
      echo "  L$ln (before the first heading): $CLIPPED"
    fi
  done 3< "$TMP/lines" 4< "$TMP/secs"
  if [ "$nlines" -gt "$MAX_LINES" ]; then
    echo "  ... $((nlines - MAX_LINES)) more line(s) (raise --max-lines)"
  fi
done < "$TMP/files"

# --- [S] uncommitted changes of the knowledge repository ---

if [ -z "$KNOWLEDGE_ROOT" ]; then
  echo "[S] not checked: the knowledge directory was not scanned"
elif ! command -v git >/dev/null 2>&1; then
  echo "[S] not checked: git not found"
elif ! git -C "$KNOWLEDGE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[S] not checked: the knowledge directory is not a git repository"
elif ! git -C "$KNOWLEDGE_ROOT" -c core.quotePath=false -c status.relativePaths=true \
       status --short --untracked-files=all -- . ':(exclude)projects' > "$TMP/status" 2>/dev/null; then
  echo "[S] not checked: git status failed in $KNOWLEDGE_ROOT"
elif [ ! -s "$TMP/status" ]; then
  echo "[S] uncommitted changes in the knowledge repository: none"
else
  n=$(wc -l < "$TMP/status" | tr -d ' ')
  echo "[S] uncommitted changes in the knowledge repository: $n (paths from the knowledge directory; not in the history yet — another session may be writing them)"
  head -n "$STATUS_LIMIT" "$TMP/status" | sed 's/^/  /'
  if [ "$n" -gt "$STATUS_LIMIT" ]; then
    echo "  ... ($((n - STATUS_LIMIT)) more)"
  fi
fi

# --- Close ---

if [ -s "$TMP/err" ]; then
  sed 's/^warning: //; s/^/warning: /' "$TMP/err" | awk '!seen[$0]++' | head -n "$STATUS_LIMIT"
  wn=$(awk '!seen[$0]++' "$TMP/err" | wc -l | tr -d ' ')
  if [ "$wn" -gt "$STATUS_LIMIT" ]; then
    echo "warning: ... ($((wn - STATUS_LIMIT)) more)"
  fi
fi
if [ -n "$NOT_SCANNED" ] || [ -s "$TMP/err" ]; then
  echo "status=partial"
  echo "[/$TAG]"
  exit 1
fi
echo "status=ok"
echo "[/$TAG]"
exit 0
