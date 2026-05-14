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
