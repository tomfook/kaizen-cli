#!/bin/bash
# test-kaizen-check-knowledge.sh — Regression tests for Check 6
# (broken anchors / section references) in kaizen-check-knowledge.sh.
#
# Usage: bash framework/bin/test-kaizen-check-knowledge.sh
# Exit codes:
#   0 = all assertions passed, or Check 6 skipped because python3 is absent
#   1 = at least one assertion failed
#
# The anchor / section normalization is subtle and false-positive-prone, so
# this guards the normalization rules and the scoping (code blocks, projects/,
# duplicate filenames) against regression.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/kaizen-check-knowledge.sh"

if [ ! -f "$CHECK_SCRIPT" ]; then
    echo "FAIL: check script not found: $CHECK_SCRIPT" >&2
    exit 1
fi

pass=0
fail=0
ok()  { echo "PASS: $1"; pass=$((pass + 1)); }
bad() { echo "FAIL: $1" >&2; fail=$((fail + 1)); }

# assert_contains <needle> <haystack> <label>
assert_contains() {
    if printf '%s' "$2" | grep -qF -- "$1"; then ok "$3"; else bad "$3 (expected to find: $1)"; fi
}
# assert_not_contains <needle> <haystack> <label>
assert_not_contains() {
    if printf '%s' "$2" | grep -qF -- "$1"; then bad "$3 (unexpectedly found: $1)"; else ok "$3"; fi
}

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 not available — Check 6 assertions skipped (script degrades gracefully)"
    exit 0
fi

# ---- Fixture ------------------------------------------------------------

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/guides" "$FIX/dir_a" "$FIX/dir_b" "$FIX/projects/details"

cat > "$FIX/guides/target.md" <<'EOF'
# Setup Guide

**Last updated**: 2026-06-01

## 設定方法

### Advanced Options

- **DynamoDB**: subcategory bullet treated as a heading-equivalent
EOF

cat > "$FIX/guides/source.md" <<'EOF'
# Source

**Last updated**: 2026-06-01

- valid ascii anchor: [a](./target.md#setup-guide)
- valid japanese anchor: [b](./target.md#設定方法)
- broken anchor: [c](./target.md#does-not-exist)
- valid section ref: `target.md § Advanced Options`
- valid bold-bullet ref: `target.md § DynamoDB`
- broken section ref: `target.md § Nonexistent Section`
- missing file ref: `ghost.md § Whatever`
- ref into projects target: [d](../projects/details/p.md#whatever)

```
[anchor in code block](./target.md#ignored-in-code)
```
EOF

# Duplicate filename across two dirs + a plain-text ref that resolves by name.
printf '# A\n\n**Last updated**: 2026-06-01\n\n## X\n' > "$FIX/dir_a/dupe.md"
printf '# B\n\n**Last updated**: 2026-06-01\n\n## X\n' > "$FIX/dir_b/dupe.md"
printf '# Uses dupe\n\n**Last updated**: 2026-06-01\n\n- `dupe.md § X`\n' > "$FIX/guides/usesdupe.md"

# projects/ is registry-synced and must be excluded as a *source* entirely.
printf '# P\n\n- broken but ignored: [x](../../guides/target.md#totally-bogus-anchor)\n' > "$FIX/projects/details/p.md"

# ---- Run + extract the Check 6 section ----------------------------------

OUT="$(KAIZEN_KNOWLEDGE_DIR="$FIX" bash "$CHECK_SCRIPT" 2>&1)"
SECT="$(printf '%s\n' "$OUT" | sed -n '/^### Broken anchors/,$p')"

# ---- Assertions ---------------------------------------------------------

assert_not_contains "setup-guide"        "$SECT" "valid ascii anchor not flagged"
assert_not_contains "設定方法"            "$SECT" "valid japanese anchor not flagged"
assert_contains     "does-not-exist"     "$SECT" "broken anchor flagged"
assert_not_contains "Advanced Options"   "$SECT" "valid section ref not flagged"
assert_not_contains "DynamoDB"           "$SECT" "valid bold-bullet ref not flagged"
assert_contains     "Nonexistent Section" "$SECT" "broken section ref flagged"
assert_contains     "referenced file not found" "$SECT" "missing-file section ref flagged"
assert_not_contains "ignored-in-code"    "$SECT" "anchor inside code block ignored"
assert_contains     "multiple files named dupe.md" "$SECT" "duplicate filename warned"
assert_not_contains "totally-bogus-anchor" "$SECT" "projects/ source file excluded"
assert_not_contains "p.md#whatever"      "$SECT" "ref into projects/ target skipped (not indexed)"

# ---- Best-effort graceful-degradation test ------------------------------
# Build a PATH that has the coreutils the script needs but NOT python3, and
# confirm Check 6 prints the skip note instead of failing. Skipped if the
# minimal PATH cannot be constructed.

DEGRADE_BIN="$(mktemp -d)"
needed="date find sort wc tr grep sed head basename dirname realpath"
degrade_ready=1
for b in $needed; do
    bp="$(command -v "$b" 2>/dev/null || true)"
    if [ -z "$bp" ]; then degrade_ready=0; break; fi
    ln -s "$bp" "$DEGRADE_BIN/$b"
done
if [ "$degrade_ready" -eq 1 ]; then
    # Invoke via the shebang (/bin/bash) so PATH need not contain bash itself.
    DEG_OUT="$(PATH="$DEGRADE_BIN" KAIZEN_KNOWLEDGE_DIR="$FIX" "$CHECK_SCRIPT" 2>&1 || true)"
    assert_contains "python3 not found" "$DEG_OUT" "graceful degradation when python3 absent"
else
    echo "SKIP: could not build a python3-less PATH — degradation test skipped"
fi
rm -rf "$DEGRADE_BIN"

# ---- Summary ------------------------------------------------------------

echo ""
echo "----"
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
