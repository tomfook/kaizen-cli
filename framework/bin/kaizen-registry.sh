#!/bin/bash
# kaizen-registry.sh — Project registry: mirror a project's summary and
# learnings into the knowledge directory, and regenerate projects/INDEX.md
# from the mirrors.
#
# Usage:
#   kaizen-registry.sh register   <registry_dir> [<project_dir>] [--expect-id <id>]
#   kaizen-registry.sh sync-index <registry_dir> [--drop <project-id>] [--dry-run]
#   kaizen-registry.sh status     <registry_dir> [<project_dir>]
#
#   <registry_dir>  The knowledge directory of the registry — the project's
#                   knowledge/ link can be passed as is.
#   <project_dir>   Project root (default: the current directory). The source
#                   files are <project_dir>/docs/PROJECT_SUMMARY.md and
#                   <project_dir>/docs/LEARNINGS.md.
#
# The registry is derived data. The source of truth is each project's own
# docs/; nothing under projects/ is edited by hand:
#   projects/details/<id>.md    copy of docs/PROJECT_SUMMARY.md   (register)
#   projects/learnings/<id>.md  copy of docs/LEARNINGS.md         (register)
#   projects/INDEX.md           table generated from details/*.md (sync-index)
#
# register
#   Copies the two files. The project id is read from the frontmatter of
#   docs/PROJECT_SUMMARY.md (project.id) — it is not an argument, so a mirror
#   cannot be written under another name by mistake. --expect-id stops with an
#   error when the frontmatter says something else. Does not touch INDEX.md.
#   `registry: false` in the frontmatter: nothing is copied.
#   LEARNINGS.md is copied once it has an entry (a `### ` heading), and from
#   then on every time, so the mirror never keeps entries the source dropped.
#   The `learnings=` line always says what happened and why.
#
# sync-index
#   Rebuilds the table of projects/INDEX.md (the rows under the `| ID |`
#   header) from the frontmatter of details/*.md. The text before and after
#   the table is kept. Idempotent. Rows are ordered by `created`, then id;
#   projects without `created` come last.
#   A row whose project has no usable details file is carried over unchanged
#   and reported (kept_without_details) — a registry that was maintained by
#   hand loses nothing. Such a row is removed only with --drop <id>, which is
#   what kaizen-unregister.sh passes.
#   INDEX.md is created from the template when it does not exist.
#   --dry-run reports what would change and writes nothing.
#   Warnings (none of these is visible otherwise): two details files with the
#   same id, a details file whose name differs from its id, a details file
#   without usable frontmatter, a learnings file without a details file, and
#   mirrors with uncommitted changes (they are baked into the table as they are).
#
# status
#   Read-only. Compares the project's docs/ with its mirrors and tells whether
#   INDEX.md is current and whether the mirrors are committed.
#
# Frontmatter: a restricted reader, not a YAML parser. It reads the scalar
# keys id, name, status, created, updated, registry and the list `keywords`
# (flow `[a, b]` or block `- a`) directly under a top-level `project:` key.
#
# Output: a [kaizen-registry-<subcommand>] block of key=value and
# `label: text` lines.
#
# Exit codes:
#   register / sync-index: 0 = done (status=ok | skipped), 1 = error (nothing
#                          was written), 2 = usage error
#   status:                0 = in sync, 1 = drift (stale or missing mirror,
#                          INDEX out of date, uncommitted mirror), 2 = usage
#                          error, 3 = cannot determine

set -uo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KAIZEN_CLI_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SEP=$'\037'
LIST_LIMIT=20

WORK=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; }
trap cleanup EXIT

usage() {
  cat >&2 <<'EOF'
Usage: kaizen-registry.sh register   <registry_dir> [<project_dir>] [--expect-id <id>]
       kaizen-registry.sh sync-index <registry_dir> [--drop <project-id>] [--dry-run]
       kaizen-registry.sh status     <registry_dir> [<project_dir>]
EOF
}

# --- awk: frontmatter reader -------------------------------------------------
# Prints one line: state, id, name, status, keywords, created, updated,
# registry — separated by 0x1f. state is ok | no-frontmatter | no-project.
IFS= read -r -d '' PARSE_AWK <<'AWK' || true
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function clean(s) { gsub(/[\t\r\037]/, " ", s); return trim(s) }
function indent_of(s,   t) { t = s; sub(/[^ \t].*$/, "", t); return length(t) }
# Position of the first `ch` outside quotes, or 0.
function find_unquoted(s, ch,   i, n, c, q) {
  n = length(s); q = ""
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (q != "") {
      if (q == "\"" && c == "\\") { i++; continue }
      if (c == q) q = ""
      continue
    }
    if (c == "\"" || c == SQ) { q = c; continue }
    if (c == ch) return i
  }
  return 0
}
# One scalar: "double quoted", 'single quoted', or plain up to a ` #` comment.
function scalar(s,   q, out, i, n, c) {
  s = trim(s)
  q = substr(s, 1, 1)
  n = length(s)
  if (q == "\"") {
    out = ""
    for (i = 2; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "\\" && i < n) {
        i++; c = substr(s, i, 1)
        if (c == "n" || c == "t") c = " "
        out = out c
        continue
      }
      if (c == "\"") break
      out = out c
    }
    return clean(out)
  }
  if (q == SQ) {
    out = ""
    for (i = 2; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == SQ) {
        if (substr(s, i + 1, 1) == SQ) { out = out SQ; i++; continue }
        break
      }
      out = out c
    }
    return clean(out)
  }
  if (q == "#") return ""
  i = match(s, /[ \t]#/)
  if (i) s = substr(s, 1, i - 1)
  s = clean(s)
  if (s == "null" || s == "~") return ""
  return s
}
# Items of a flow sequence (the text between [ and ]), joined with ", ".
function flow_items(body,   out, pos, item, v) {
  out = ""
  while (1) {
    pos = find_unquoted(body, ",")
    item = (pos ? substr(body, 1, pos - 1) : body)
    v = scalar(item)
    if (v != "") out = (out == "" ? v : out ", " v)
    if (!pos) break
    body = substr(body, pos + 1)
  }
  return out
}
BEGIN {
  SQ = sprintf("%c", 39)
  BOM = sprintf("%c%c%c", 239, 187, 191)
  state = "start"; in_project = 0; seen_project = 0; child = -1
  list_key = ""; flow = ""; flow_key = ""
}
NR == 1 {
  line = $0
  if (substr(line, 1, 3) == BOM) line = substr(line, 4)
  sub(/\r$/, "", line)
  if (line ~ /^---[ \t]*$/) { state = "fm"; next }
  state = "none"
  exit
}
state != "fm" { next }
{
  line = $0
  sub(/\r$/, "", line)
  if (line ~ /^---[ \t]*$/ || line ~ /^\.\.\.[ \t]*$/) { state = "done"; exit }
  if (flow != "") {
    flow = flow " " line
    pos = find_unquoted(flow, "]")
    if (pos) { val[flow_key] = flow_items(substr(flow, 2, pos - 2)); flow = "" }
    next
  }
  if (line ~ /^[ \t]*$/ || line ~ /^[ \t]*#/) next
  ind = indent_of(line)
  body = trim(line)
  if (ind == 0) {
    list_key = ""
    in_project = 0
    if (body ~ /^project[ \t]*:/) {
      rest = body
      sub(/^project[ \t]*:/, "", rest)
      if (scalar(rest) == "") { in_project = 1; seen_project = 1; child = -1 }
    }
    next
  }
  if (!in_project) next
  if (child < 0) child = ind
  if (list_key != "" && (body == "-" || body ~ /^-[ \t]/) && ind >= child) {
    item = body
    sub(/^-[ \t]*/, "", item)
    item = scalar(item)
    if (item != "") val[list_key] = (val[list_key] == "" ? item : val[list_key] ", " item)
    next
  }
  if (ind != child) next
  list_key = ""
  if (body !~ /^[A-Za-z_][A-Za-z0-9_-]*[ \t]*:[ \t]/ && body !~ /^[A-Za-z_][A-Za-z0-9_-]*[ \t]*:$/) next
  key = body
  sub(/[ \t]*:.*$/, "", key)
  rest = body
  sub(/^[^:]*:/, "", rest)
  rest = trim(rest)
  if (key == "keywords") {
    if (substr(rest, 1, 1) == "[") {
      pos = find_unquoted(rest, "]")
      if (pos) val[key] = flow_items(substr(rest, 2, pos - 2))
      else { flow = rest; flow_key = key }
    } else if (scalar(rest) == "") {
      list_key = key
      val[key] = ""
    } else {
      val[key] = scalar(rest)
    }
    next
  }
  val[key] = scalar(rest)
}
END {
  st = "ok"
  if (state != "done") st = "no-frontmatter"
  else if (!seen_project) st = "no-project"
  reg = tolower(val["registry"])
  reg = (reg == "false" || reg == "no" || reg == "off") ? "false" : "true"
  printf "%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\n", st, val["id"], val["name"], val["status"], val["keywords"], val["created"], val["updated"], reg
}
AWK

# --- awk: INDEX generator ----------------------------------------------------
# Input: `mode=recs <records> mode=index <INDEX.md>`; -v out=<new INDEX>,
# -v drop=<id>. Prints the report lines; exits 1 when the table cannot be found.
IFS= read -r -d '' GEN_AWK <<'AWK' || true
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function esc(s,   n, parts, i, o) {
  n = split(s, parts, "|")
  o = parts[1]
  for (i = 2; i <= n; i++) o = o "\\|" parts[i]
  return o
}
function warn(s) { warns[++nwarn] = s }
function join_ids(arr, n,   i, o) {
  o = ""
  for (i = 1; i <= n; i++) o = (o == "" ? arr[i] : o "," arr[i])
  return o
}
# Sorts ids[1..n] by skey[id] (byte order).
function sort_ids(ids, n,   i, j, t) {
  for (i = 2; i <= n; i++) {
    t = ids[i]
    for (j = i - 1; j >= 1 && skey[ids[j]] > skey[t]; j--) ids[j + 1] = ids[j]
    ids[j + 1] = t
  }
}
mode == "recs" {
  split($0, f, "\037")
  base = f[1]
  if (f[2] != "ok") {
    warn("details/" base ".md: " (f[2] == "no-project" ? "no `project:` mapping in the frontmatter" : "no frontmatter") " — not used for the table")
    unusable[base] = 1
    next
  }
  id = (f[3] != "" ? f[3] : base)
  if (f[9] == "false") { excluded[id] = 1; next }
  if (id != base) warn("details/" base ".md declares id '" id "' — the file name differs from the id (a mirror written under another name?)")
  if (id in wbase) {
    if (wbase[id] != id && base == id) { loser = wbase[id]; take = 1 } else { loser = base; take = 0 }
    warn("duplicate id '" id "': using details/" (take ? base : wbase[id]) ".md, ignoring details/" loser ".md")
    if (!take) next
  }
  wbase[id] = base
  wname[id] = (f[4] != "" ? f[4] : id)
  wstat[id] = (f[5] != "" ? f[5] : "planning")
  wkw[id] = f[6]
  wcreated[id] = f[7]
  wupdated[id] = f[8]
  next
}
mode == "index" { L[++nl] = $0 }
END {
  h = 0
  for (i = 1; i <= nl; i++) {
    t = tolower(L[i])
    if (t ~ /^\|[ \t]*id[ \t]*\|/) { h = i; break }
  }
  if (!h) { print "error=table header not found in projects/INDEX.md (a row starting with `| ID |`); the file was not changed"; exit 1 }
  if (L[h + 1] !~ /^\|[ \t]*:?-/) { print "error=no separator row under the table header of projects/INDEX.md; the file was not changed"; exit 1 }
  t = trim(L[h]); sub(/^\|/, "", t); sub(/\|$/, "", t)
  ncol = split(t, parts, "|")
  if (ncol != 5) { print "error=projects/INDEX.md has " ncol " columns; expected 5 (ID, name, status, keywords, updated); the file was not changed"; exit 1 }

  nold = 0
  for (i = h + 2; i <= nl && L[i] ~ /^\|/; i++) {
    split(L[i], parts, "|")
    oid = trim(parts[2])
    if (oid == "") { warn("row without an id was dropped: " L[i]); continue }
    if (oid in oldrow) { warn("second row for id '" oid "' was dropped: " L[i]); continue }
    oldrow[oid] = L[i]
    oldids[++nold] = oid
  }
  rowend = i - 1

  nw = 0
  for (id in wbase) {
    wids[++nw] = id
    skey[id] = (wcreated[id] != "" ? "0" : "1") "\034" wcreated[id] "\034" id
  }
  sort_ids(wids, nw)

  nkept = 0; nrem = 0
  for (i = 1; i <= nold; i++) {
    oid = oldids[i]
    if (oid in wbase) continue
    if (oid in excluded) { removed[++nrem] = oid; continue }
    if (oid == drop) { removed[++nrem] = oid; continue }
    kept[++nkept] = oid
    skey[oid] = oid ""
    why[oid] = (oid in unusable) ? "details/" oid ".md has no usable frontmatter" : "no details/" oid ".md"
  }
  sort_ids(kept, nkept)
  if (drop != "" && (drop in wbase)) warn("--drop " drop " ignored: details/" wbase[drop] ".md still declares that id")

  nadd = 0; nupd = 0
  for (i = 1; i <= h + 1; i++) print L[i] > out
  for (i = 1; i <= nw; i++) {
    id = wids[i]
    row = "| " esc(id) " | " esc(wname[id]) " | " esc(wstat[id]) " | " esc(wkw[id]) " | " esc(wupdated[id]) " |"
    print row > out
    if (!(id in oldrow)) added[++nadd] = id
    else if (oldrow[id] != row) updated[++nupd] = id
  }
  for (i = 1; i <= nkept; i++) print oldrow[kept[i]] > out
  for (i = rowend + 1; i <= nl; i++) print L[i] > out
  close(out)

  print "projects=" (nw + nkept)
  print "added=" nadd
  print "updated=" nupd
  print "removed=" nrem
  print "kept_without_details=" nkept
  if (nadd) print "added_ids=" join_ids(added, nadd)
  if (nupd) print "updated_ids=" join_ids(updated, nupd)
  if (nrem) print "removed_ids=" join_ids(removed, nrem)
  for (i = 1; i <= nkept; i++) print "kept: " kept[i] " (" why[kept[i]] "; row carried over as is — register the project, or unregister it to remove the row)"
  for (i = 1; i <= nwarn; i++) print "warning: " warns[i]
}
AWK

# --- helpers -----------------------------------------------------------------

# open_block <name> / close_block <status> <exit code>
BLOCK=""
open_block() { BLOCK="kaizen-registry-$1"; echo "[$BLOCK]"; }
close_block() {
  echo "status=$1"
  echo "[/$BLOCK]"
  exit "$2"
}
# fail <message> — error inside an open block; nothing was written.
fail() {
  echo "error=$1"
  close_block error 1
}

# resolve_dir <dir> — physical path, or empty.
resolve_dir() { (cd "$1" 2>/dev/null && pwd -P) || true; }

# parse_fm <file> — sets FM_STATE FM_ID FM_NAME FM_STATUS FM_KEYWORDS FM_CREATED FM_UPDATED FM_REGISTRY
parse_fm() {
  local line
  line="$(awk "$PARSE_AWK" "$1" 2>/dev/null)" || line=""
  [ -n "$line" ] || line="no-frontmatter${SEP}${SEP}${SEP}${SEP}${SEP}${SEP}${SEP}true"
  IFS="$SEP" read -r FM_STATE FM_ID FM_NAME FM_STATUS FM_KEYWORDS FM_CREATED FM_UPDATED FM_REGISTRY <<EOF
$line
EOF
}

# scan_details <details_dir> <records file> — one record per details/*.md,
# in byte order of the file names: base, then the fields of parse_fm.
scan_details() {
  local dir="$1" out="$2" f base line
  : > "$out"
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    base="${base%.md}"
    line="$(awk "$PARSE_AWK" "$f" 2>/dev/null)" || line=""
    [ -n "$line" ] || line="no-frontmatter${SEP}${SEP}${SEP}${SEP}${SEP}${SEP}${SEP}true"
    printf '%s%s%s\n' "$base" "$SEP" "$line" >> "$out"
  done
}

# print_list <label> <text> — one `label: line` per line, capped.
print_list() {
  local label="$1" text="$2" total
  [ -z "$text" ] && return 0
  total=$(printf '%s\n' "$text" | wc -l | tr -d ' ')
  printf '%s\n' "$text" | head -n "$LIST_LIMIT" | sed "s/^/$label: /"
  if [ "$total" -gt "$LIST_LIMIT" ]; then
    echo "$label: ... ($((total - LIST_LIMIT)) more)"
  fi
}

is_safe_id() { printf '%s\n' "$1" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._-]*$'; }

# entry_count <LEARNINGS.md> — number of `### ` headings.
entry_count() { grep -c '^### ' "$1" 2>/dev/null || true; }

# copy_mirror <src> <dst> — prints created | updated | unchanged; returns 1 on failure.
copy_mirror() {
  local src="$1" dst="$2" result="created"
  if [ -f "$dst" ]; then
    if cmp -s "$src" "$dst"; then echo "unchanged"; return 0; fi
    result="updated"
  fi
  mkdir -p "$(dirname "$dst")" || return 1
  cp "$src" "$dst.tmp.$$" || return 1
  mv "$dst.tmp.$$" "$dst" || { rm -f "$dst.tmp.$$"; return 1; }
  echo "$result"
}

# template_index <registry_dir> — path of the INDEX template for the registry's language.
template_index() {
  local lang="en" t
  if [ -f "$1/.lang" ]; then
    lang="$(tr -d '[:space:]' < "$1/.lang")"
  fi
  t="$KAIZEN_CLI_DIR/framework/templates/$lang/knowledge/projects/INDEX.md.template"
  [ -f "$t" ] || t="$KAIZEN_CLI_DIR/framework/templates/en/knowledge/projects/INDEX.md.template"
  echo "$t"
}

# build_index <registry_dir> <drop id> — fills $WORK: report, index.new,
# index.state (current | outdated | missing). Returns 1 when the table cannot
# be rebuilt (the report then holds the error= line).
build_index() {
  local reg="$1" drop="$2" index="$1/projects/INDEX.md" base
  scan_details "$reg/projects/details" "$WORK/recs"
  if [ -f "$index" ]; then
    base="$index"
  else
    base="$(template_index "$reg")"
    if [ ! -f "$base" ]; then
      echo "error=projects/INDEX.md does not exist and its template was not found: $base" > "$WORK/report"
      return 1
    fi
  fi
  rm -f "$WORK/index.new"
  if ! awk -v out="$WORK/index.new" -v drop="$drop" "$GEN_AWK" mode=recs "$WORK/recs" mode=index "$base" > "$WORK/report"; then
    grep -q '^error=' "$WORK/report" || echo "error=could not rebuild the table of projects/INDEX.md" > "$WORK/report"
    return 1
  fi
  if [ ! -f "$index" ]; then
    echo "missing" > "$WORK/index.state"
  elif cmp -s "$WORK/index.new" "$index"; then
    echo "current" > "$WORK/index.state"
  else
    echo "outdated" > "$WORK/index.state"
  fi
  return 0
}

# registry_warnings <registry_dir> — warnings that need the file system, not the table.
registry_warnings() {
  local reg="$1" f base
  for f in "$reg"/projects/learnings/*.md; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    base="${base%.md}"
    if [ ! -f "$reg/projects/details/$base.md" ]; then
      echo "warning: learnings/$base.md has no details/$base.md (a mirror left behind, or written under another name)"
    fi
  done
}

# uncommitted <registry_dir> <pathspec>... — `git status --short` lines, or nothing without git.
uncommitted() {
  local reg="$1"
  shift
  command -v git >/dev/null 2>&1 || return 0
  git -C "$reg" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git -C "$reg" status --short --untracked-files=all -- "$@" 2>/dev/null || true
}

# require_registry <arg> — sets REG (physical path) or exits with a usage error.
require_registry() {
  if [ -z "${1:-}" ]; then usage; exit 2; fi
  REG="$(resolve_dir "$1")"
}

# --- register ----------------------------------------------------------------

do_register() {
  local reg_arg="" project_arg="" expect="" a
  while [ $# -gt 0 ]; do
    a="$1"
    case "$a" in
      --expect-id)
        [ $# -ge 2 ] || { usage; exit 2; }
        expect="$2"; shift 2 ;;
      --*) usage; exit 2 ;;
      *)
        if [ -z "$reg_arg" ]; then reg_arg="$a"
        elif [ -z "$project_arg" ]; then project_arg="$a"
        else usage; exit 2
        fi
        shift ;;
    esac
  done
  require_registry "$reg_arg"
  open_block register
  [ -n "$REG" ] || fail "registry directory does not exist: $reg_arg"

  local project summary learnings
  project="$(resolve_dir "${project_arg:-.}")"
  [ -n "$project" ] || fail "project directory does not exist: ${project_arg:-.}"
  summary="$project/docs/PROJECT_SUMMARY.md"
  learnings="$project/docs/LEARNINGS.md"

  if [ ! -f "$summary" ]; then
    local guess="${project##*/}"
    if [ -f "$REG/projects/details/$guess.md" ]; then
      echo "source_lost=projects/details/$guess.md"
      fail "docs/PROJECT_SUMMARY.md not found in $project, but the registry has details/$guess.md. The project file is the source: restore it from the mirror, then register"
    fi
    fail "docs/PROJECT_SUMMARY.md not found in $project"
  fi

  parse_fm "$summary"
  if [ "$FM_STATE" != "ok" ]; then
    fail "docs/PROJECT_SUMMARY.md has no frontmatter with a \`project:\` mapping (see framework/templates/*/docs/PROJECT_SUMMARY.md.template)"
  fi
  [ -n "$FM_ID" ] || fail "project.id is empty in the frontmatter of docs/PROJECT_SUMMARY.md"
  is_safe_id "$FM_ID" || fail "project.id '$FM_ID' cannot be used as a file name (allowed: letters, digits, '.', '_', '-'; must start with a letter or digit)"
  local id="$FM_ID"
  echo "project_id=$id"
  if [ -n "$expect" ] && [ "$expect" != "$id" ]; then
    fail "id mismatch: docs/PROJECT_SUMMARY.md says '$id', expected '$expect'. Nothing was written — decide which id is right and make the frontmatter say it"
  fi

  local details_dst="$REG/projects/details/$id.md"
  local learnings_dst="$REG/projects/learnings/$id.md"

  if [ "$FM_REGISTRY" = "false" ]; then
    echo "reason=registry: false in the frontmatter"
    if [ -f "$details_dst" ] || [ -f "$learnings_dst" ]; then
      echo "warning: mirrors of '$id' exist in the registry although the project opted out — remove them with /kaizen-unregister-project $id"
    fi
    close_block skipped 0
  fi

  mkdir -p "$REG/projects/details" "$REG/projects/learnings" || fail "cannot create projects/ under $REG"

  local result
  result="$(copy_mirror "$summary" "$details_dst")" || fail "cannot write projects/details/$id.md"
  echo "details=$result"

  if [ ! -f "$learnings" ]; then
    if [ -f "$learnings_dst" ]; then
      echo "learnings=kept"
      echo "learnings_reason=docs/LEARNINGS.md not found; the existing mirror was left as is"
      echo "warning: learnings/$id.md exists but docs/LEARNINGS.md does not — the project file is the source; restore it from the mirror if it was lost"
    else
      echo "learnings=not-synced"
      echo "learnings_reason=no docs/LEARNINGS.md"
    fi
  elif [ "$(entry_count "$learnings")" = "0" ] && [ ! -f "$learnings_dst" ]; then
    echo "learnings=not-synced"
    echo "learnings_reason=docs/LEARNINGS.md has no entry yet (no \`### \` heading)"
  else
    result="$(copy_mirror "$learnings" "$learnings_dst")" || fail "cannot write projects/learnings/$id.md"
    echo "learnings=$result"
  fi

  # Another details file that declares the same id.
  WORK="$(mktemp -d)" || fail "cannot create a temporary directory"
  scan_details "$REG/projects/details" "$WORK/recs"
  local base st other_id _rest
  while IFS="$SEP" read -r base st other_id _rest; do
    [ "$st" = "ok" ] || continue
    [ "$base" != "$id" ] || continue
    if [ "${other_id:-$base}" = "$id" ]; then
      echo "warning: details/$base.md also declares id '$id' — one of the two is a mirror written under another name; remove it"
    fi
  done < "$WORK/recs"

  close_block ok 0
}

# --- sync-index --------------------------------------------------------------

do_sync_index() {
  local reg_arg="" drop="" dry=0 a
  while [ $# -gt 0 ]; do
    a="$1"
    case "$a" in
      --drop)
        [ $# -ge 2 ] || { usage; exit 2; }
        drop="$2"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      --*) usage; exit 2 ;;
      *)
        if [ -z "$reg_arg" ]; then reg_arg="$a"; else usage; exit 2; fi
        shift ;;
    esac
  done
  require_registry "$reg_arg"
  open_block sync-index
  [ -n "$REG" ] || fail "registry directory does not exist: $reg_arg"

  WORK="$(mktemp -d)" || fail "cannot create a temporary directory"
  if ! build_index "$REG" "$drop"; then
    cat "$WORK/report"
    close_block error 1
  fi

  local state index="$REG/projects/INDEX.md" result
  state="$(cat "$WORK/index.state")"
  case "$state" in
    current) result="unchanged" ;;
    outdated) result="updated" ;;
    *) result="created" ;;
  esac
  if [ "$state" != "current" ]; then
    if [ "$dry" -eq 1 ]; then
      result="would-be-$result"
    else
      mkdir -p "$REG/projects" || fail "cannot create projects/ under $REG"
      cp "$WORK/index.new" "$index.tmp.$$" && mv "$index.tmp.$$" "$index" || {
        rm -f "$index.tmp.$$"
        fail "cannot write projects/INDEX.md"
      }
    fi
  fi
  echo "index=$result"
  cat "$WORK/report"
  registry_warnings "$REG"
  local wip
  wip="$(uncommitted "$REG" projects/details)"
  if [ -n "$wip" ]; then
    echo "uncommitted_details=$(printf '%s\n' "$wip" | wc -l | tr -d ' ')"
    print_list "uncommitted" "$wip"
  fi
  close_block ok 0
}

# --- status ------------------------------------------------------------------

do_status() {
  local reg_arg="${1:-}" project_arg="${2:-}"
  if [ $# -gt 2 ]; then usage; exit 2; fi
  require_registry "$reg_arg"
  open_block status
  if [ -z "$REG" ]; then
    echo "error=registry directory does not exist: $reg_arg"
    close_block error 3
  fi
  local project summary learnings
  project="$(resolve_dir "${project_arg:-.}")"
  if [ -z "$project" ]; then
    echo "error=project directory does not exist: ${project_arg:-.}"
    close_block error 3
  fi
  summary="$project/docs/PROJECT_SUMMARY.md"
  learnings="$project/docs/LEARNINGS.md"

  if [ ! -f "$summary" ]; then
    local guess="${project##*/}"
    if [ -f "$REG/projects/details/$guess.md" ]; then
      echo "source_lost=projects/details/$guess.md"
      echo "error=docs/PROJECT_SUMMARY.md not found, but the registry has details/$guess.md. The project file is the source: restore it from the mirror"
    else
      echo "error=docs/PROJECT_SUMMARY.md not found in $project"
    fi
    close_block error 3
  fi
  parse_fm "$summary"
  if [ "$FM_STATE" != "ok" ] || [ -z "$FM_ID" ] || ! is_safe_id "$FM_ID"; then
    echo "error=docs/PROJECT_SUMMARY.md has no usable project.id in its frontmatter"
    close_block error 3
  fi
  local id="$FM_ID" drift=0
  echo "project_id=$id"
  local details_dst="$REG/projects/details/$id.md"
  local learnings_dst="$REG/projects/learnings/$id.md"

  if [ "$FM_REGISTRY" = "false" ]; then
    echo "registered=no (registry: false in the frontmatter)"
    if [ -f "$details_dst" ] || [ -f "$learnings_dst" ]; then
      echo "warning: mirrors of '$id' exist in the registry although the project opted out — remove them with /kaizen-unregister-project $id"
    fi
    close_block ok 0
  fi

  local stale=0
  if [ ! -f "$details_dst" ]; then
    echo "details=missing"; drift=1
  elif cmp -s "$summary" "$details_dst"; then
    echo "details=match"
  else
    echo "details=stale"; drift=1; stale=1
  fi

  if [ ! -f "$learnings" ]; then
    if [ -f "$learnings_dst" ]; then
      echo "learnings=source-missing"
      echo "warning: learnings/$id.md exists but docs/LEARNINGS.md does not — the project file is the source; restore it from the mirror if it was lost"
    else
      echo "learnings=not-synced (no docs/LEARNINGS.md)"
    fi
  elif [ ! -f "$learnings_dst" ]; then
    if [ "$(entry_count "$learnings")" = "0" ]; then
      echo "learnings=not-synced (no entry yet)"
    else
      echo "learnings=missing"; drift=1
    fi
  elif cmp -s "$learnings" "$learnings_dst"; then
    echo "learnings=match"
  else
    echo "learnings=stale"; drift=1; stale=1
  fi

  WORK="$(mktemp -d)" || { echo "error=cannot create a temporary directory"; close_block error 3; }
  if build_index "$REG" ""; then
    local state
    state="$(cat "$WORK/index.state")"
    echo "index=$state"
    [ "$state" = "current" ] || drift=1
  else
    echo "index=unknown"
    sed 's/^error=/index_error=/' "$WORK/report"
    drift=1
  fi

  local wip
  wip="$(uncommitted "$REG" projects/INDEX.md "projects/details/$id.md" "projects/learnings/$id.md")"
  if [ -n "$wip" ]; then
    echo "uncommitted=$(printf '%s\n' "$wip" | wc -l | tr -d ' ')"
    print_list "uncommitted" "$wip"
    drift=1
  else
    echo "uncommitted=0"
  fi

  if [ "$drift" -eq 1 ]; then
    if [ "$stale" -eq 1 ]; then
      echo "note=before syncing, diff the project file against its mirror: text that exists only in the mirror was written there directly, and is lost when the project file is copied over it"
    fi
    echo "fix=/kaizen-update-docs (it runs register and sync-index, then commits the three registry files)"
    close_block drift 1
  fi
  close_block clean 0
}

# --- Main dispatch -----------------------------------------------------------

case "${1:-}" in
  register) shift; do_register "$@" ;;
  sync-index) shift; do_sync_index "$@" ;;
  status) shift; do_status "$@" ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac
