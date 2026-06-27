#!/bin/bash
# kaizen-check-knowledge.sh — Mechanical checks for knowledge/ files (Phase 1).
#
# Usage: bash kaizen-check-knowledge.sh [subdir]
#   subdir: path relative to $KAIZEN_KNOWLEDGE_DIR (optional; default: whole tree)
#
# Note: knowledge/projects/ is always excluded from scanning. The files under
# projects/details/ and projects/learnings/ are registry data automatically
# synced from each project's PROJECT_SUMMARY.md / LEARNINGS.md by
# /kaizen-update-docs — they are not knowledge content and must not be audited.
#
# Checks:
#   1. File inventory (line count, size warning)
#   2. Freshness (days since last updated)
#   3. Files missing a last-updated line
#   4. INDEX.md line-count deviation (±50 lines)
#   5. Broken relative links (within $KAIZEN_KNOWLEDGE_DIR)
#   6. Broken anchors / section references (requires python3; skipped with a
#      note if python3 is absent — keeps the script free of a hard dependency)
#
# Output: Markdown. Intended to be passed directly to kaizen-knowledge-auditor.
# Exit codes: 0=ok, 1=env/usage error

set -uo pipefail

if [ -z "${KAIZEN_KNOWLEDGE_DIR:-}" ]; then
    echo "Error: KAIZEN_KNOWLEDGE_DIR is not set" >&2
    exit 1
fi

KNOWLEDGE_DIR="$(cd "$KAIZEN_KNOWLEDGE_DIR" 2>/dev/null && pwd || true)"
if [ -z "$KNOWLEDGE_DIR" ] || [ ! -d "$KNOWLEDGE_DIR" ]; then
    echo "Error: KAIZEN_KNOWLEDGE_DIR does not point to a directory: $KAIZEN_KNOWLEDGE_DIR" >&2
    exit 1
fi

TARGET_SUBDIR="${1:-}"
if [ -n "$TARGET_SUBDIR" ]; then
    SCAN_PATH="$KNOWLEDGE_DIR/$TARGET_SUBDIR"
else
    SCAN_PATH="$KNOWLEDGE_DIR"
fi

if [ ! -d "$SCAN_PATH" ]; then
    echo "Error: directory does not exist: $SCAN_PATH" >&2
    exit 1
fi

TODAY_TS=$(date +%s)
files=$(find "$SCAN_PATH" -name "*.md" -type f -not -path '*/projects/*' | sort)

# Extract last-updated date from a markdown file. Supports both:
#   **Last updated**: YYYY-MM-DD
#   **最終更新**: YYYY-MM-DD
# Returns the date string on stdout (may be empty).
extract_updated() {
    local file="$1"
    grep -E "^\*\*(Last updated|最終更新)\*\*: " "$file" 2>/dev/null \
        | head -1 | sed 's/.*: //' | tr -d '[:space:]' || true
}

# Check if a file has any last-updated line.
has_updated() {
    grep -qE "^\*\*(Last updated|最終更新)\*\*: " "$1"
}

# ---- Header -------------------------------------------------------------

if [ -n "$TARGET_SUBDIR" ]; then
    target_label="$TARGET_SUBDIR"
else
    target_label="(whole knowledge/ tree)"
fi

echo "## Mechanical check results"
echo ""
echo "- **target**: \`$target_label\`"
echo "- **date**: $(date +%Y-%m-%d)"
echo ""

# ---- 1+2. File inventory (line count / freshness) ----------------------

echo "### File inventory (line count, freshness)"
echo ""
echo "| file | lines | size | last updated | days | freshness |"
echo "|------|------:|------|--------------|-----:|-----------|"

while IFS= read -r file; do
    [ -z "$file" ] && continue
    relpath="${file#$KNOWLEDGE_DIR/}"
    lines=$(wc -l < "$file" | tr -d ' ')

    if [ "$lines" -gt 800 ]; then
        size_warn="🔴 >800"
    elif [ "$lines" -gt 600 ]; then
        size_warn="⚠️ >600"
    else
        size_warn="-"
    fi

    updated="$(extract_updated "$file")"

    if [ -z "$updated" ]; then
        echo "| $relpath | $lines | $size_warn | - | - | - |"
        continue
    fi

    updated_ts=$(date -d "$updated" +%s 2>/dev/null || echo "")
    if [ -z "$updated_ts" ]; then
        # Try BSD date (macOS)
        updated_ts=$(date -j -f "%Y-%m-%d" "$updated" +%s 2>/dev/null || echo "")
    fi
    if [ -z "$updated_ts" ]; then
        echo "| $relpath | $lines | $size_warn | $updated | (unparseable) | ❓ |"
        continue
    fi

    days=$(( (TODAY_TS - updated_ts) / 86400 ))

    if [ "$days" -gt 180 ]; then
        freshness="🔴"
    elif [ "$days" -gt 90 ]; then
        freshness="⚠️"
    else
        freshness="✅"
    fi

    echo "| $relpath | $lines | $size_warn | $updated | ${days} | $freshness |"
done <<< "$files"

# ---- 3. Missing last-updated (excludes INDEX.md and templates) ---------

echo ""
echo "### Missing last-updated line"
echo ""
no_updated=""
while IFS= read -r file; do
    [ -z "$file" ] && continue
    fname=$(basename "$file")
    [[ "$fname" == "INDEX.md" ]] && continue
    [[ "$file" == */templates/* ]] && continue

    if ! has_updated "$file"; then
        no_updated="${no_updated}- ${file#$KNOWLEDGE_DIR/}\n"
    fi
done <<< "$files"

if [ -z "$no_updated" ]; then
    echo "none"
else
    printf '%b' "$no_updated"
fi

# ---- 4. INDEX.md line-count deviation ----------------------------------

echo ""
echo "### INDEX.md line-count deviation (±50)"
echo ""

deviations=""
index_files=$(find "$SCAN_PATH" -name "INDEX.md" -type f -not -path '*/projects/*' | sort)

while IFS= read -r index; do
    [ -z "$index" ] && continue
    index_dir=$(dirname "$index")
    index_relpath="${index#$KNOWLEDGE_DIR/}"

    while IFS= read -r line; do
        # Extract filename from link `(./path.md)`
        fname=$(echo "$line" | grep -oE '\(\./[^)]+\.md\)' | head -1 | sed 's|^(\./||; s|)$||')
        # Extract estimated count. Accept `~N`, `~N行`, `~N lines`.
        est=$(echo "$line" | grep -oE '~[0-9]+' | head -1 | sed 's/^~//')

        [ -z "$fname" ] && continue
        [ -z "$est" ] && continue

        target_file="$index_dir/$fname"
        if [ ! -f "$target_file" ]; then
            deviations="${deviations}- ${index_relpath}: \`$fname\` missing from link target\n"
            continue
        fi

        actual=$(wc -l < "$target_file" | tr -d ' ')
        diff=$(( actual - est ))
        abs_diff=${diff#-}

        if [ "$abs_diff" -gt 50 ]; then
            sign=""
            [ "$diff" -gt 0 ] && sign="+"
            deviations="${deviations}- ${index_relpath}: \`$fname\` listed ~${est} vs actual ${actual} (${sign}${diff})\n"
        fi
    done < "$index"
done <<< "$index_files"

if [ -z "$deviations" ]; then
    echo "none"
else
    printf '%b' "$deviations"
fi

# ---- 5. Broken relative links ------------------------------------------

echo ""
echo "### Broken relative links (within knowledge/)"
echo ""

broken_links=""
while IFS= read -r file; do
    [ -z "$file" ] && continue
    file_dir=$(dirname "$file")
    file_relpath="${file#$KNOWLEDGE_DIR/}"

    # Skip fenced code blocks and inline-code spans to avoid flagging examples.
    in_code_block=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*\`\`\` ]]; then
            in_code_block=$((1 - in_code_block))
            continue
        fi
        [ "$in_code_block" -eq 1 ] && continue

        clean_line=$(echo "$line" | sed 's/`[^`]*`//g')

        # Match relative links: (./foo.md), (../foo/bar.md) — anchors allowed.
        for link in $(echo "$clean_line" | grep -oE '\(\.\.?/[^)]+\.md(#[^)]*)?\)' 2>/dev/null); do
            link_path=$(echo "$link" | sed 's/^(//; s/)$//; s/#.*$//')
            [ -z "$link_path" ] && continue

            target_path=$(realpath -m "$file_dir/$link_path" 2>/dev/null || echo "")
            [ -z "$target_path" ] && continue

            # Only check links that resolve inside $KNOWLEDGE_DIR.
            case "$target_path" in
                "$KNOWLEDGE_DIR"/*) ;;
                *) continue ;;
            esac

            if [ ! -f "$target_path" ]; then
                broken_links="${broken_links}- ${file_relpath}: \`$link_path\` not found\n"
            fi
        done
    done < "$file"
done <<< "$files"

if [ -z "$broken_links" ]; then
    echo "none"
else
    printf '%b' "$broken_links"
fi

# ---- 6. Broken anchors / section references ----------------------------
# Validates (a) markdown-link anchors `[text](./path.md#anchor)` and
# (b) plain-text section refs `` `X.md § Y` `` against the target file's
# headings, using GitHub-style loose Unicode normalization. Requires
# python3 — bash cannot reliably normalize Japanese / emoji headings.
# Degrades gracefully (prints a note, skips the check) when python3 is absent.

echo ""
echo "### Broken anchors / section references (target heading not found)"
echo ""

if ! command -v python3 >/dev/null 2>&1; then
    echo "(python3 not found — anchor/section check skipped)"
else
    python3 - "$KNOWLEDGE_DIR" "$SCAN_PATH" <<'PYEOF'
"""Detect broken anchors and plain-text section references.

Two kinds of references are checked, both scoped to knowledge/ files:
  1. Markdown-link anchors `[text](./path.md#anchor)`.
  2. Plain-text section refs `` `X.md § Y` `` (multi-level `§ A § B § C`
     matches against the final level, C).

Heading matching uses a loose, GitHub-flavored normalization rather than a
strict emulation: lowercase + URL-encoding removal + keep alnum/-/_/space
(drop everything else, including emoji and full-width punctuation) + each
space -> hyphen. Mixed scripts or duplicated headings (`-1` suffixes) can
yield false positives, so results are advisory.
"""
import re
import sys
from pathlib import Path

KNOWLEDGE_DIR = Path(sys.argv[1]).resolve()  # repo boundary + display root
SCAN_PATH = Path(sys.argv[2]).resolve()      # rglob root

URL_ENC = re.compile(r'%[0-9a-fA-F]{2}')
HEADING = re.compile(r'^(#{1,6})\s+(.+?)\s*$')
ANCHOR_LINK = re.compile(r'\(\.\.?/[^)]+\.md#[^)]+\)')
CODE_FENCE = re.compile(r'^\s*```')
INLINE_CODE = re.compile(r'`[^`]*`')
TEXT_SECTION_REF = re.compile(r'`([A-Za-z_][A-Za-z0-9_-]*\.md)\s*§\s*([^`]+)`')
QUOTE_LINE = re.compile(r'^\s*>')
# bold-prefixed list bullet treated as a heading-equivalent, e.g.
# `- **DynamoDB**:` referenced via `§ DynamoDB`.
LIST_BULLET = re.compile(r'^\s*[-*+]\s+\*\*([^*]+?)\*\*\s*[:.]')


def normalize(s: str) -> str:
    """GitHub-style loose anchor normalization (lowercase, drop non
    alnum/-/_/space, each space -> hyphen). isalnum() is Unicode-aware,
    so Japanese characters are kept and emoji are dropped."""
    s = s.lower()
    s = URL_ENC.sub('', s)
    s = ''.join(c for c in s if c.isalnum() or c in '-_' or c.isspace())
    s = ''.join('-' if c.isspace() else c for c in s)
    return s.strip('-')


def extract_headings(path: Path) -> set[str]:
    """Normalized headings + bold-prefixed list bullets (heading-equivalent),
    excluding fenced code blocks."""
    out: set[str] = set()
    in_code = False
    try:
        text = path.read_text(encoding='utf-8')
    except (OSError, UnicodeDecodeError):
        return out
    for line in text.splitlines():
        if CODE_FENCE.match(line):
            in_code = not in_code
            continue
        if in_code:
            continue
        m = HEADING.match(line)
        if m:
            out.add(normalize(m.group(2)))
            continue
        m2 = LIST_BULLET.match(line)
        if m2:
            out.add(normalize(m2.group(1)))
    return out


def extract_anchor_links(path: Path):
    """Yield (link_path, anchor) for anchored md links, skipping code."""
    in_code = False
    try:
        text = path.read_text(encoding='utf-8')
    except (OSError, UnicodeDecodeError):
        return
    for line in text.splitlines():
        if CODE_FENCE.match(line):
            in_code = not in_code
            continue
        if in_code:
            continue
        clean = INLINE_CODE.sub('', line)
        for match in ANCHOR_LINK.findall(clean):
            inner = match[1:-1]  # strip outer parens
            link_path, _, anchor = inner.partition('#')
            if link_path and anchor:
                yield link_path, anchor


def extract_text_section_refs(path: Path):
    """Yield (filename, final-level section) for plain-text `X.md § Y`
    refs, skipping fenced code blocks and block quotes."""
    in_code = False
    try:
        text = path.read_text(encoding='utf-8')
    except (OSError, UnicodeDecodeError):
        return
    for line in text.splitlines():
        if CODE_FENCE.match(line):
            in_code = not in_code
            continue
        if in_code:
            continue
        if QUOTE_LINE.match(line):
            continue
        for filename, section_path in TEXT_SECTION_REF.findall(line):
            levels = [s.strip() for s in section_path.split('§')]
            yield filename, levels[-1]


# Scan set: *.md under SCAN_PATH, excluding registry-synced projects/.
md_files = sorted({
    p for p in SCAN_PATH.rglob('*.md')
    if 'projects' not in p.relative_to(KNOWLEDGE_DIR).parts
})

# Pass 1: precompute the normalized heading set for each indexed file.
file_headings: dict[Path, set[str]] = {
    f.resolve(): extract_headings(f) for f in md_files
}
# filename -> indexed paths (plain-text refs resolve by filename).
filename_index: dict[str, list[Path]] = {}
for f in md_files:
    filename_index.setdefault(f.name, []).append(f.resolve())

# Pass 2: markdown-link anchors.
broken_link = []
for src in md_files:
    for link_path, anchor in extract_anchor_links(src):
        try:
            target = (src.parent / link_path).resolve()
        except (OSError, RuntimeError):
            continue
        try:
            target.relative_to(KNOWLEDGE_DIR)  # skip refs outside knowledge/
        except ValueError:
            continue
        headings = file_headings.get(target)
        if headings is None:
            # Target not indexed: missing file (reported by check 5) or an
            # excluded path such as projects/. Skip to avoid false positives.
            continue
        if normalize(anchor) not in headings:
            rel = src.relative_to(KNOWLEDGE_DIR)
            broken_link.append(f"- {rel}: `{link_path}#{anchor}` (no matching heading)")

# Pass 2.5: plain-text section refs.
broken_text = []
for src in md_files:
    rel = src.relative_to(KNOWLEDGE_DIR)
    for filename, section in extract_text_section_refs(src):
        candidates = filename_index.get(filename, [])
        if not candidates:
            broken_text.append(f"- {rel}: `{filename} § {section}` (referenced file not found)")
            continue
        if len(candidates) > 1:
            cand_str = ', '.join(str(c.relative_to(KNOWLEDGE_DIR)) for c in candidates)
            broken_text.append(f"- {rel}: `{filename} § {section}` (multiple files named {filename}: {cand_str})")
            continue
        if normalize(section) not in file_headings.get(candidates[0], set()):
            broken_text.append(f"- {rel}: `{filename} § {section}` (no matching heading)")

if broken_link or broken_text:
    if broken_link:
        print("**Markdown links ([text](path#anchor)):**")
        print("\n".join(broken_link))
        print()
    if broken_text:
        print("**Plain-text refs (`X.md § Y`):**")
        print("\n".join(broken_text))
        print()
    print("> Note: loose GitHub-style normalization (lowercase + keep alnum/-/_/space + space->hyphen). Duplicate-heading `-1`/`-2` suffixes are not modeled, and plain-text refs resolve by filename only — verify flagged items manually.")
else:
    print("none")
PYEOF
fi
