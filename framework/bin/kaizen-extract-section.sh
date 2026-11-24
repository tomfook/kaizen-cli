#!/bin/bash
# kaizen-extract-section.sh — Extract one section of a Markdown file by heading boundary.
#
# Usage:
#   kaizen-extract-section.sh <file> '<heading>'            # section body (stops before the next heading, subheadings included)
#   kaizen-extract-section.sh --subtree <file> '<heading>'  # body plus subheadings (stops at a heading of the same or a higher level)
#   kaizen-extract-section.sh --list <file>                 # headings with line numbers (fenced code excluded)
#   kaizen-extract-section.sh --bytes <file>                # bytes per heading (flat: up to the next heading) and the total
#
# Why a script instead of an ad-hoc awk range: a one-liner such as
#   awk '/^#+ Heading/{f=1;next} f&&/^#+ /{exit} f'
# returns a partial section or nothing — without an error — when the section
# contains a `# comment` inside a code fence, when another heading starts with
# the same words, or when the heading contains regex metacharacters. This
# script hides those guards behind one interface and never answers silently.
#
# Heading match:
#   - Fixed string, whole title (no regex, no prefix or substring match).
#     The leading `#`s, trailing blanks, and a closing ` ##` are stripped first.
#   - Level-independent (`##` and `###` are matched the same way).
#   - Backticks are optional: an exact match wins; otherwise the titles are
#     compared with backticks removed, so the text of a `§ Heading` reference
#     can be passed as is. Such a match is noted on stderr.
#   - Pass the title only — not `## Title`.
#
# Code fences follow CommonMark: ``` and ~~~, 3 or more characters, indented,
# opened right after a list marker (`- `, `1. `), closed by the same character
# at the same length or longer. A line such as ```x``` (inline code) does not
# open a fence. Lines inside a fence are never headings; they are part of the
# output.
#
# Exit codes (a partial result or an empty result is never returned silently):
#   0 = exactly one heading matched (an empty section is noted on stderr)
#   1 = heading not found (stderr lists headings that contain the text)
#   2 = more than one heading matched (stderr lists the line numbers)
#   3 = usage error, missing or unreadable file, awk failure
#
# CRLF: a trailing CR is ignored when detecting headings and fences. Output
# lines and byte counts keep the CR.
#
# --bytes: the first row is the preamble (front matter and anything before the
# first heading; omitted when empty). Values are flat — add the subheadings by
# line number to weigh a whole `##`. Bytes, not characters (LC_ALL=C).
#   Heaviest first: ... --bytes <file> | sort -t: -k2 -n -r | head
#
# Portability: bash 3.2 and POSIX awk (no interval expressions, no gawk
# extensions). `-v BINMODE=3` keeps CR bytes under gawk on Windows and is an
# unused variable elsewhere.

set -uo pipefail

usage() {
    cat >&2 <<'EOF'
Usage:
  kaizen-extract-section.sh <file> '<heading>'            section body (stops before the next heading)
  kaizen-extract-section.sh --subtree <file> '<heading>'  body plus subheadings
  kaizen-extract-section.sh --list <file>                 headings with line numbers
  kaizen-extract-section.sh --bytes <file>                bytes per heading and the total
Exit codes: 0 = one match, 1 = not found, 2 = several matches, 3 = usage or file error
EOF
}

# The three mode tokens are accepted in any position: `<file> --list` used to
# be the common slip, and reading it as a heading named "--list" answers
# "not found", which looks like a fact about the file. Any other `--...` after
# the file name is a heading title (`## --apply steps` is a legitimate heading).
MODE=extract
NPOS=0
FILE=""
NEEDLE=""
EXTRA=""
for a in "$@"; do
    case "$a" in
        --list|--bytes|--subtree)
            if [ "$MODE" != extract ]; then
                echo "Error: only one mode may be given (--$MODE and $a)" >&2
                usage
                exit 3
            fi
            MODE="${a#--}"
            continue ;;
        -h|--help)
            if [ "$NPOS" -eq 0 ]; then
                usage
                exit 0
            fi ;;
        --*)
            if [ "$NPOS" -eq 0 ]; then
                echo "Error: unknown option: $a" >&2
                usage
                exit 3
            fi ;;
    esac
    NPOS=$((NPOS + 1))
    if [ "$NPOS" -eq 1 ]; then
        FILE="$a"
    elif [ "$NPOS" -eq 2 ] && [ "$MODE" != list ] && [ "$MODE" != bytes ]; then
        NEEDLE="$a"
    else
        EXTRA="${EXTRA:+$EXTRA }$a"
    fi
done

case "$MODE" in
    list|bytes) WANT=1; TAKES="--$MODE takes a file name only" ;;
    *)          WANT=2; TAKES="extraction takes a file name and one heading" ;;
esac
# A mode given after the positionals reclassifies them: `<file> X --list`.
if [ "$WANT" -eq 1 ] && [ -n "$NEEDLE" ]; then
    EXTRA="$NEEDLE${EXTRA:+ $EXTRA}"
    NEEDLE=""
fi
if [ -n "$EXTRA" ]; then
    echo "Error: unexpected extra argument: $EXTRA ($TAKES; quote a heading that contains spaces)" >&2
    usage
    exit 3
fi

if [ -z "$FILE" ]; then
    usage
    exit 3
fi
if [ ! -f "$FILE" ]; then
    echo "Error: file not found: $FILE" >&2
    exit 3
fi
if [ ! -r "$FILE" ]; then
    echo "Error: cannot read file: $FILE" >&2
    exit 3
fi

awk_failed() {
    # 141 = the reader (`| head`) closed first. The extraction itself
    # succeeded, so this is not a failure.
    [ "$1" = 141 ] && exit 0
    echo "Error: awk failed (exit code $1): $FILE" >&2
    exit 3
}

# run_awk <awk arguments...> — runs awk with its stdout on ours and returns its
# exit code, except that "the reader closed the pipe" is always reported as 141.
# awk is killed by SIGPIPE (141) on some systems; on others (BSD awk, or any awk
# when SIGPIPE is ignored) it prints a write error and exits 2, which would be
# indistinguishable from a real failure. stderr is passed through otherwise.
run_awk() {
    local err rc
    exec 3>&1
    err=$(LC_ALL=C awk "$@" 2>&1 1>&3)
    rc=$?
    exec 3>&-
    if [ "$rc" -ne 0 ]; then
        case "$err" in
            *"write error"*|*"write failure"*|*"Broken pipe"*) return 141 ;;
        esac
    fi
    [ -n "$err" ] && printf '%s\n' "$err" >&2
    return "$rc"
}

# Shared by the three modes.
#   hlevel(line)       -> 1..6 for an ATX heading line, 0 otherwise
#   fence_update(line) -> 1 when the line is a fence line; state in inf, fch, flen
SHARED_AWK='
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
'

if [ "$MODE" = list ]; then
    run_awk -v BINMODE=3 "$SHARED_AWK"'
        { sub(/\r$/, "") }
        { if (fence_update($0)) next }
        !inf && hlevel($0) > 0 { print NR ": " $0 }
    ' "$FILE" || awk_failed $?
    exit 0
fi

if [ "$MODE" = bytes ]; then
    SIZE=$(wc -c < "$FILE" | tr -d ' ') || awk_failed $?
    run_awk -v BINMODE=3 -v size="$SIZE" "$SHARED_AWK"'
        BEGIN { n = 0; cur = 0; line[0] = 1; label[0] = "(preamble: before the first heading)" }
        {
            rawlen = length($0); sub(/\r$/, "")
            isf = fence_update($0)
            if (!isf && !inf && hlevel($0) > 0) { n++; cur = n; line[n] = NR; label[n] = $0 }
            bytes[cur] += rawlen + 1
        }
        END {
            sum = 0; for (i = 0; i <= n; i++) sum += bytes[i]
            bytes[cur] += size - sum        # a file without a trailing newline: correct the +1 by the real size
            for (i = 0; i <= n; i++) if (i > 0 || bytes[0] > 0) printf "%d: %d B  %s\n", line[i], bytes[i], label[i]
            printf "total: %d B\n", size
        }
    ' "$FILE" || awk_failed $?
    exit 0
fi

if [ -z "$NEEDLE" ]; then
    if [ "$NPOS" -ge 2 ]; then
        echo "Error: the heading name is empty" >&2
    fi
    usage
    exit 3
fi

# The heading goes through ENVIRON: `-v` interprets backslash escapes, which a
# fixed string must not go through. The file is read twice: the first pass
# collects the headings and decides the match (exact first, then with backticks
# removed); the second pass copies the body from the decided line. In one pass,
# an exact match appearing after a backtick-insensitive one could not be taken.
export H="$NEEDLE"
run_awk -v BINMODE=3 -v mode="$MODE" "$SHARED_AWK"'
    function heading_title(line,    t) {
        t = line
        sub(/^#+[ \t]+/, "", t)
        sub(/[ \t]+$/, "", t)
        sub(/[ \t]+#+$/, "", t)
        sub(/[ \t]+$/, "", t)
        return t
    }
    function strip_bt(s) { gsub(/`/, "", s); return s }
    function decide(    i) {
        decided = 1
        if (ne > 0)      { hits = ne; for (i = 1; i <= ne; i++) hitline[i] = exact[i] }
        else if (nn > 0) { hits = nn; vianorm = 1; for (i = 1; i <= nn; i++) hitline[i] = norm[i] }
        if (hits == 1) target = hitline[1]
    }
    BEGIN {
        needle = ENVIRON["H"]; sneedle = strip_bt(needle)
        ne = 0; nn = 0; ncand = 0; hits = 0; cap = 0; n = 0
        decided = 0; vianorm = 0; target = -1; childline = 0
    }
    FNR == 1 { inf = 0; if (NR > 1) decide() }
    NR == FNR {
        sub(/\r$/, "")
        if (fence_update($0)) next
        if (!inf && hlevel($0) > 0) {
            title = heading_title($0); stitle = strip_bt(title)
            if (title == needle)        { exact[++ne] = FNR }
            else if (stitle == sneedle) { norm[++nn] = FNR; normline[nn] = $0 }
            if (index(stitle, sneedle) > 0) { cand[++ncand] = FNR ": " $0 }
        }
        next
    }
    {
        raw = $0; sub(/\r$/, "")
        isfence = fence_update($0)
        lvl = (isfence || inf) ? 0 : hlevel($0)
        if (lvl > 0) {
            if (cap && (mode != "subtree" || lvl <= startlvl)) {
                # Remember that the default mode stopped at a subheading (for the stderr note).
                if (mode != "subtree" && lvl > startlvl) { childline = FNR; childtext = $0 }
                cap = 0
            }
            if (FNR == target) { cap = 1; startlvl = lvl; next }
        }
        if (cap) { buf[++n] = raw }
    }
    END {
        if (!decided) decide()
        if (hits == 0) {
            printf "Error: heading not found: %s\n", needle > "/dev/stderr"
            if (ncand > 0) {
                print "  Headings that contain the text (not used: only a whole-title match counts):" > "/dev/stderr"
                for (i = 1; i <= ncand; i++) print "    " cand[i] > "/dev/stderr"
            } else {
                print "  Hint: list the headings with kaizen-extract-section.sh --list <file>" > "/dev/stderr"
            }
            exit 11
        }
        if (hits > 1) {
            printf "Error: %d headings match (lines ", hits > "/dev/stderr"
            for (i = 1; i <= hits; i++) printf "%s%d", (i > 1 ? ", " : ""), hitline[i] > "/dev/stderr"
            print "). Make the heading unique in the file, then retry." > "/dev/stderr"
            exit 12
        }
        if (vianorm) {
            printf "Note: matched with backticks ignored (line %d: %s)\n", hitline[1], normline[1] > "/dev/stderr"
        }
        nonblank = 0
        for (i = 1; i <= n; i++) if (buf[i] ~ /[^ \t\r]/) { nonblank = 1; break }
        if (!nonblank) {
            printf "Note: the section is empty (no non-blank line between the heading at line %d and the next heading)\n", hitline[1] > "/dev/stderr"
        }
        if (childline > 0) {
            printf "Note: stopped before a subheading (line %d: %s). Use --subtree to include it.\n", childline, childtext > "/dev/stderr"
        }
        for (i = 1; i <= n; i++) print buf[i]
        exit 0
    }
' "$FILE" "$FILE"
rc=$?
# awk itself exits 2 on a fatal error, which would read as "several matches",
# so the script uses 11 / 12 internally and maps anything else to 3.
case "$rc" in
    0)  exit 0 ;;
    11) exit 1 ;;
    12) exit 2 ;;
    *)  awk_failed "$rc" ;;
esac
