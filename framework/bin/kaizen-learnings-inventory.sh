#!/bin/bash
# kaizen-learnings-inventory.sh — Read the markers of a project's docs/LEARNINGS.md:
# the lessons waiting to be promoted, and how far the next inventory has to look.
#
# Usage:
#   kaizen-learnings-inventory.sh [--file <LEARNINGS.md>] [--knowledge <dir>]
#
#   --file <path>        The lessons file. Default: docs/LEARNINGS.md
#   --knowledge <dir>    Knowledge directory (the registry that the project's
#                        knowledge/ link points to). Default: ./knowledge
#
# Read-only. It reports two kinds of marker lines, both written by
# /kaizen-update-docs. A marker is a list item that starts with a bold label;
# the English and the Japanese label are read the same way, and a line inside a
# code fence is never a marker (the entry format in the template is an example,
# not a candidate).
#
#   - **Promotion candidate**: <why>          a lesson judged to belong in
#   - **昇格候補**: <理由>                      knowledge/ and not written there yet.
#       ... (deferred until: <condition>)     Written as the last bullet of its
#       ... （先送り: <再検出条件>）             entry, or in the inventory section for
#                                             a candidate that has no entry. With a
#                                             condition it is `deferred`, without one
#                                             it is `open`.
#   - **Inventory**: YYYY-MM-DD (knowledge@<commit>) — <result>
#   - **棚卸し**: YYYY-MM-DD (knowledge@<commit>) — <結果>
#                                             one line per day an inventory was
#                                             made. <commit> is the commit of the
#                                             knowledge repository the lessons were
#                                             compared with.
#
# Why a script instead of grep: a search for the label also hits the example in
# the entry format, every sentence that mentions the word, and the record that
# says a candidate was handled — and a search that failed prints nothing, the
# same as "no candidate". Why a commit instead of a date: `git log --since=<date>`
# starts at the current time of day unless a time is given, and a commit pulled
# from another machine can be older than the date it arrived on.
#
# Scope of the next inventory. Whether a lesson has graduated is a comparison
# with knowledge/, so the answer changes whenever knowledge/ changes. The scope
# is `narrowed` only when the last inventory line names a commit that still
# exists and fewer than half of the knowledge files changed since; then the
# changed files are listed. In every other case it is `full`, with the reason.
# projects/ at the top of the knowledge directory is left out: it holds the
# mirrors of each project's own docs.
#
# Output: a [kaizen-learnings-inventory] block.
#   file=<path>
#   entries=<n>                                 `### ` headings outside code fences
#   candidates=<n> (open <n>, deferred <n>)
#   candidate: L<line> [open|deferred] (§ <heading>): <the line>
#   inventories=<n> (limit 3)                   distinct days
#   last_inventory=<YYYY-MM-DD | none>
#   baseline=<knowledge@<commit> | none>        from the newest inventory line
#   knowledge_head=<knowledge@<commit> | none>  what the knowledge repository is at now
#   scope=full | narrowed
#   scope_reason=<text>
#   changed=<n> of <m> file(s) since <baseline>   (scope=narrowed, or full because too many changed)
#   changed: <path inside the knowledge directory>
#   record=<YYYY-MM-DD> (knowledge@<commit>)    what follows the label on the line to write
#   warning: <text>                             a marker that is not in the expected form
#   status=ok | attention | no-file | error
#
# Exit codes:
#   0 = read; nothing needs a decision (status=ok), or there is no lessons file
#       (status=no-file)
#   1 = read; an open candidate or a warning needs a decision (status=attention)
#   2 = usage error
#   3 = cannot determine (unreadable file, awk failure) — the block is not a result
#
# Portability: bash 3.2, POSIX awk (no interval expressions), git optional.
# The script runs in the C locale: labels are matched as bytes.

set -uo pipefail
export LC_ALL=C

GEN_LIMIT=3
OLD_LINE_BYTES=240

usage() {
    cat >&2 <<'EOF'
Usage:
  kaizen-learnings-inventory.sh [--file <LEARNINGS.md>] [--knowledge <dir>]
Exit codes: 0 = nothing to decide (or no file), 1 = open candidate or warning,
            2 = usage error, 3 = cannot determine
EOF
}

FILE="docs/LEARNINGS.md"
KDIR="knowledge"
while [ $# -gt 0 ]; do
    case "$1" in
        --file)
            [ $# -ge 2 ] || { echo "Error: --file needs a path" >&2; usage; exit 2; }
            FILE="$2"; shift 2 ;;
        --knowledge)
            [ $# -ge 2 ] || { echo "Error: --knowledge needs a directory" >&2; usage; exit 2; }
            KDIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Error: unexpected argument: $1" >&2; usage; exit 2 ;;
    esac
done

echo "[kaizen-learnings-inventory]"
echo "file=$FILE"

if [ ! -e "$FILE" ]; then
    echo "note=there is no lessons file here: nothing to inventory, and no candidate is waiting"
    echo "status=no-file"
    exit 0
fi
if [ ! -f "$FILE" ] || [ ! -r "$FILE" ]; then
    echo "error=cannot read $FILE"
    echo "status=error"
    exit 3
fi

# One pass over the file. Lines for the reader are printed as they are; lines
# that start with `@` are values for the rest of this script.
SCAN=$(awk -v BINMODE=3 -v limit="$GEN_LIMIT" -v oldmax="$OLD_LINE_BYTES" '
    function hlevel(line) {
        if (match(line, /^#+ /) && RLENGTH <= 7) return RLENGTH - 1
        return 0
    }
    function fence_update(line,    body, ch, len, rest) {
        if (match(line, /^[ \t]*(([-*+]|[0-9]+[.)])[ \t]+)?[ \t]*(```+|~~~+)/)) {
            body = substr(line, RSTART, RLENGTH)
            sub(/^[ \t]*(([-*+]|[0-9]+[.)])[ \t]+)?[ \t]*/, "", body)
            ch = substr(body, 1, 1); len = length(body)
            rest = substr(line, RSTART + RLENGTH)
            if (!inf) {
                if (ch == "`" && index(rest, "`") > 0) return 0
                inf = 1; fch = ch; flen = len; return 1
            }
            sub(/^[ \t]*/, "", rest)
            if (ch == fch && len >= flen && rest == "") { inf = 0; return 1 }
        }
        return 0
    }
    function heading_title(line,    t) {
        t = line
        sub(/^#+[ \t]+/, "", t)
        sub(/[ \t]+$/, "", t)
        sub(/[ \t]+#+$/, "", t)
        sub(/[ \t]+$/, "", t)
        return t
    }
    # The text of a list item, or "" when the line is not one.
    function item_text(line,    s) {
        s = line
        sub(/^[ \t]*/, "", s)
        if (s !~ /^[-*+][ \t]+/) return ""
        sub(/^[-*+][ \t]+/, "", s)
        return s
    }
    # 1 when s starts with **label** and a colon; the text after it goes to REST.
    function after_label(s, label,    p, r) {
        p = "**" label "**"
        if (tolower(substr(s, 1, length(p))) != tolower(p)) return 0
        r = substr(s, length(p) + 1)
        if (substr(r, 1, 1) == ":") { REST = substr(r, 2); return 1 }
        if (substr(r, 1, length(FWCOLON)) == FWCOLON) { REST = substr(r, length(FWCOLON) + 1); return 1 }
        return 0
    }
    function warn(text) { warns[++nwarn] = text }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    # The condition of a deferral, or "". NOCOND is set when the word is there but no condition follows it.
    function deferral(rest,    i, tail, word) {
        NOCOND = 0
        word = "deferred until"
        i = index(tolower(rest), word)
        if (i == 0) { word = JA_DEFER; i = index(rest, word) }
        if (i == 0) return ""
        tail = substr(rest, i + length(word))
        if (substr(tail, 1, 1) == ":") tail = substr(tail, 2)
        else if (substr(tail, 1, length(FWCOLON)) == FWCOLON) tail = substr(tail, length(FWCOLON) + 1)
        else { NOCOND = 1; return "" }
        gsub(/[ \t)]/, "", tail)
        while ((i = index(tail, FWCLOSE)) > 0) tail = substr(tail, 1, i - 1) substr(tail, i + length(FWCLOSE))
        if (tail == "") NOCOND = 1
        return tail
    }
    BEGIN {
        FWCOLON = "："; FWCLOSE = "）"; JA_DEFER = "先送り"
        JA_CAND = "昇格候補"; JA_INV = "棚卸し"
        heading = "(before the first heading)"
        entries = 0; ncand = 0; nopen = 0; ndefer = 0; ninv = 0; nwarn = 0; ndates = 0
    }
    {
        sub(/\r$/, "")
        if (fence_update($0)) next
        if (inf) next
        lvl = hlevel($0)
        if (lvl > 0) {
            heading = heading_title($0)
            if (lvl == 3) entries++
            next
        }
        s = item_text($0)
        if (s == "") next
        if (after_label(s, JA_CAND) || after_label(s, "Promotion candidate")) {
            ncand++
            state = "open"
            if (trim(REST) == "") warn("L" NR ": a candidate without a reason — say in one line why the lesson belongs in knowledge/")
            if (deferral(REST) != "") state = "deferred"
            else if (NOCOND) warn("L" NR ": a deferral without a condition is read as open — write what would bring the candidate back")
            if (state == "open") nopen++; else ndefer++
            cand[ncand] = "candidate: L" NR " [" state "] (§ " heading "): " trim($0)
            next
        }
        if (after_label(s, JA_INV) || after_label(s, "Inventory")) {
            r = trim(REST)
            if (!match(r, /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
                warn("L" NR ": an inventory line without a date (YYYY-MM-DD right after the label) — it is not counted")
                next
            }
            d = substr(r, 1, 10)
            ninv++
            invdate[ninv] = d; invline[ninv] = NR; invlen[ninv] = length($0)
            invhash[ninv] = ""
            if (match(r, /knowledge@[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*/))
                invhash[ninv] = substr(r, RSTART + 10, RLENGTH - 10)
            if (d in seen) warn("L" NR ": a second inventory line for " d " (first at L" seen[d] ") — keep one line per day and rewrite it on a rerun")
            else { seen[d] = NR; ndates++ }
        }
    }
    END {
        latest = 0
        for (i = 1; i <= ninv; i++) if (latest == 0 || invdate[i] > invdate[latest]) latest = i
        for (i = 1; i <= ninv; i++) {
            if (i == latest || invdate[i] == invdate[latest]) continue
            if (invlen[i] > oldmax)
                warn("L" invline[i] ": an older inventory line still carries its detail (" invlen[i] " bytes) — only the newest line keeps the detail; cut the older ones down to the date and a one-line result")
        }
        if (ndates > limit)
            warn(ndates " inventory lines (limit " limit ") — remove the oldest; the history is in git")
        print "entries=" entries
        print "candidates=" ncand " (open " nopen ", deferred " ndefer ")"
        for (i = 1; i <= ncand; i++) print cand[i]
        print "inventories=" ndates " (limit " limit ")"
        print "last_inventory=" (latest ? invdate[latest] : "none")
        print "@last=" (latest ? invdate[latest] : "")
        print "@hash=" (latest ? invhash[latest] : "")
        print "@open=" nopen
        print "@nwarn=" nwarn
        for (i = 1; i <= nwarn; i++) print "@warning: " warns[i]
    }
' "$FILE" 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "error=awk failed (exit code $rc) on $FILE"
    [ -n "$SCAN" ] && printf '%s\n' "$SCAN" | sed 's/^/awk: /'
    echo "status=error"
    exit 3
fi

value_of() { printf '%s\n' "$SCAN" | sed -n "s/^@$1=//p" | head -n 1; }
LAST="$(value_of last)"
BASE_HASH="$(value_of hash)"
OPEN="$(value_of open)"
NWARN="$(value_of nwarn)"
case "$OPEN$NWARN" in
    ''|*[!0-9]*)
        echo "error=the scan of $FILE did not finish"
        echo "status=error"
        exit 3 ;;
esac

printf '%s\n' "$SCAN" | grep -v '^@' || true
if [ -n "$BASE_HASH" ]; then
    echo "baseline=knowledge@$BASE_HASH"
else
    echo "baseline=none"
fi

# --- How far the next inventory has to look -----------------------------------

EXTRA_WARN=""
add_warning() { EXTRA_WARN="${EXTRA_WARN}warning: $1"$'\n'; NWARN=$((NWARN + 1)); }

KROOT=""
if [ -d "$KDIR" ]; then
    KROOT="$(cd "$KDIR" 2>/dev/null && pwd -P)" || KROOT=""
fi
IS_GIT=0
HEAD_HASH=""
if [ -n "$KROOT" ] && git -C "$KROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    IS_GIT=1
    HEAD_HASH="$(git -C "$KROOT" rev-parse --short HEAD 2>/dev/null)" || HEAD_HASH=""
fi
if [ -n "$HEAD_HASH" ]; then
    echo "knowledge_head=knowledge@$HEAD_HASH"
else
    echo "knowledge_head=none"
fi

SCOPE="full"
REASON=""
CHANGED=""
NCHANGED=""
NTOTAL=""
if [ -z "$KROOT" ]; then
    REASON="the knowledge directory was not found ($KDIR)"
elif [ "$IS_GIT" -eq 0 ]; then
    REASON="the knowledge directory is not a git repository, so what changed since the last inventory cannot be listed"
elif [ -z "$LAST" ]; then
    REASON="no inventory line yet"
elif [ -z "$BASE_HASH" ]; then
    REASON="the last inventory line ($LAST) names no knowledge@<commit>"
elif ! git -C "$KROOT" cat-file -e "$BASE_HASH^{commit}" 2>/dev/null; then
    REASON="the commit of the last inventory (knowledge@$BASE_HASH) is not in the knowledge repository"
else
    DIFF_OK=1
    TRACKED="$(git -C "$KROOT" -c core.quotePath=false diff --relative --name-only "$BASE_HASH" -- . ':(exclude)projects' 2>/dev/null)" || DIFF_OK=0
    UNTRACKED="$(git -C "$KROOT" -c core.quotePath=false ls-files --others --exclude-standard -- . ':(exclude)projects' 2>/dev/null)" || DIFF_OK=0
    ALL="$(git -C "$KROOT" -c core.quotePath=false ls-files --cached --others --exclude-standard -- . ':(exclude)projects' 2>/dev/null)" || DIFF_OK=0
    if [ "$DIFF_OK" -eq 0 ]; then
        REASON="git could not list the changes since knowledge@$BASE_HASH"
        add_warning "git failed in the knowledge repository — the scope falls back to full"
    else
        CHANGED="$(printf '%s\n%s\n' "$TRACKED" "$UNTRACKED" | grep -v '^$' | sort -u || true)"
        NCHANGED="$(printf '%s\n' "$CHANGED" | grep -c -v '^$' || true)"
        NTOTAL="$(printf '%s\n' "$ALL" | grep -c -v '^$' || true)"
        if [ "$NTOTAL" -eq 0 ] || [ $((NCHANGED * 2)) -ge "$NTOTAL" ]; then
            REASON="$NCHANGED of $NTOTAL knowledge file(s) changed since the last inventory — narrowing would leave out little"
        else
            SCOPE="narrowed"
            if [ "$NCHANGED" -eq 0 ]; then
                REASON="knowledge/ has not changed since the last inventory — no entry can have graduated since; judge the entries dated $LAST or later"
            else
                REASON="judge again the entries that the changed files could cover, and the entries dated $LAST or later"
            fi
        fi
    fi
fi
echo "scope=$SCOPE"
echo "scope_reason=$REASON"
if [ -n "$NCHANGED" ]; then
    echo "changed=$NCHANGED of $NTOTAL file(s) since knowledge@$BASE_HASH"
    if [ "$SCOPE" = "narrowed" ] && [ -n "$CHANGED" ]; then
        printf '%s\n' "$CHANGED" | sed 's/^/changed: /'
    fi
fi

TODAY="$(date +%Y-%m-%d)"
if [ -n "$HEAD_HASH" ]; then
    echo "record=$TODAY (knowledge@$HEAD_HASH)"
else
    echo "record=$TODAY"
fi

printf '%s\n' "$SCAN" | sed -n 's/^@warning: /warning: /p'
[ -n "$EXTRA_WARN" ] && printf '%s' "$EXTRA_WARN"

if [ "$OPEN" -gt 0 ] || [ "$NWARN" -gt 0 ]; then
    if [ "$OPEN" -gt 0 ]; then
        echo "note=an open candidate is not finished: hand it to /kaizen-reflect-learning in this session, or write the condition that brings it back"
    fi
    echo "status=attention"
    exit 1
fi
echo "status=ok"
exit 0
