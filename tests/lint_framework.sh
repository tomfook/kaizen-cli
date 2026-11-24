#!/bin/bash
# lint_framework.sh — static lint for the distributed framework
# (commands / skills / agents under framework/.claude, scripts under framework/bin)
#
# Usage: bash tests/lint_framework.sh [framework_dir]
#   framework_dir defaults to ../framework relative to this script.
#
# Guards against failures that are silent at runtime: Claude Code does not
# report a broken frontmatter (the skill or agent just stops being picked up),
# and it rewrites "$0", "$1", ... in a command or SKILL.md body when the item is
# invoked with arguments (so `awk '{print $1}'` breaks only on those runs).
#
# Rules (output: "ERROR [rule] <path>[:line]: <message>"):
#   fm-missing                SKILL.md / agent has no frontmatter block
#   fm-unclosed               frontmatter is opened but never closed
#   fm-name-missing           `name` is absent or empty
#   fm-name-mismatch          `name` differs from the skill directory / agent file name
#   fm-description-missing    `description` is absent or empty
#   fm-description-multiline  multi-line `description` not written as a block scalar (>-)
#   fm-description-colon      plain-scalar `description` contains ": " (YAML reads a key)
#   positional-var            "$<digit>" in commands/*.md or skills/*/SKILL.md
#                             (allowed: "\$1" escape, $ARGUMENTS)
#   skill-no-skillmd          skill directory without SKILL.md
#   prefix                    skill / command / agent without the kaizen- prefix
#   max-lines                 Markdown or template longer than 800 lines,
#                             script (*.sh, *.py) longer than 1500 lines
#   bin-ref                   referenced framework/bin/ script does not exist
#   sweeping-commit           inside a code fence of any .md under .claude/:
#                             `git add -A` / `--all` / `.`, or `git -C <dir> commit`
#                             without `-- <paths>`. The knowledge repository is shared;
#                             commit through framework/bin/kaizen-knowledge-commit.sh.
#                             (Prose that says not to use them is outside a fence, and a
#                             `#` comment line inside a fence is not a command.)
#
# The YAML check is a limited syntax check on purpose (no runtime dependencies):
# it reads top-level `name` / `description` only and does not parse YAML in full.
#
# Supporting files of a skill (anything other than SKILL.md) are not checked for
# positional variables: they are read with the Read tool, not expanded.
# Substitution spec: https://code.claude.com/docs/en/skills ("string substitutions").
#
# Exit codes: 0=clean, 1=violations found, 2=usage error / nothing to lint

set -uo pipefail

# Markdown is read into the model's context in full, so its size is a hard
# limit. A script is executed, not read whole: its limit only flags accretion,
# and splitting a single-file tool to satisfy a number costs more than it buys.
readonly MAX_LINES=800
readonly MAX_SCRIPT_LINES=1500

if [ "$#" -gt 1 ]; then
  echo "Usage: lint_framework.sh [framework_dir]" >&2
  exit 2
fi

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)/framework}"
if [ ! -d "$ROOT/.claude" ]; then
  echo "Error: not a framework directory (no .claude/): $ROOT" >&2
  exit 2
fi
ROOT="$(cd "$ROOT" && pwd)"

VIOLATIONS=0
N_SKILLS=0
N_COMMANDS=0
N_AGENTS=0

err() {  # <rule> <location> <message>
  VIOLATIONS=$((VIOLATIONS + 1))
  echo "ERROR [$1] $2: $3"
}

# parse_frontmatter <file> — prints one token per line:
#   nofm | unclosed | name-missing | name=<value> | desc=<missing|empty|ok|multiline|colon>
parse_frontmatter() {
  awk -v SQ="'" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function is_quote(c) { return c == "\"" || c == SQ }
    function unquote(s,   first) {
      first = substr(s, 1, 1)
      if (length(s) >= 2 && is_quote(first) && substr(s, length(s), 1) == first)
        return substr(s, 2, length(s) - 2)
      return s
    }
    function desc_state() {
      if (desc_kind == "block") return (desc_cont > 0) ? "ok" : "empty"
      if (desc_val == "") return (desc_cont > 0) ? "multiline" : "empty"
      if (desc_cont > 0) return "multiline"
      if (is_quote(substr(desc_val, 1, 1))) return (trim(unquote(desc_val)) == "") ? "empty" : "ok"
      if (index(desc_val, ": ") > 0) return "colon"
      return "ok"
    }
    { sub(/\r$/, "") }
    NR == 1 {
      if ($0 != "---") { nofm = 1; exit }
      next
    }
    $0 == "---" { closed = 1; exit }
    /^[A-Za-z_][A-Za-z0-9_-]*:/ {
      key = $0; sub(/:.*/, "", key)
      val = $0; sub(/^[^:]*:/, "", val); val = trim(val)
      cur = key
      if (key == "name") { have_name = 1; name_val = trim(unquote(val)) }
      if (key == "description") {
        have_desc = 1; desc_val = val; desc_cont = 0
        desc_kind = (val ~ /^[>|][-+0-9]*[ \t]*(#.*)?$/) ? "block" : "plain"
      }
      next
    }
    /^[ \t]+[^ \t]/ { if (cur == "description") desc_cont++ }
    END {
      if (NR == 0 || nofm) { print "nofm"; exit }
      if (!closed) { print "unclosed"; exit }
      if (have_name && name_val != "") print "name=" name_val; else print "name-missing"
      print "desc=" (have_desc ? desc_state() : "missing")
    }
  ' "$1"
}

# check_frontmatter <file> <rel> <expected_name> <required|optional>
#   optional: a missing block is fine (commands), and so are missing keys;
#             what is present must still be well-formed.
check_frontmatter() {
  local file="$1" rel="$2" expected="$3" mode="$4"
  local token

  while IFS= read -r token; do
    case "$token" in
      nofm)
        [ "$mode" = "required" ] && err fm-missing "$rel" "no frontmatter block (first line must be ---)" ;;
      unclosed)
        err fm-unclosed "$rel" "frontmatter is not closed with ---" ;;
      name-missing)
        [ "$mode" = "required" ] && err fm-name-missing "$rel" "frontmatter has no non-empty 'name'" ;;
      name=*)
        if [ "$mode" = "required" ] && [ "${token#name=}" != "$expected" ]; then
          err fm-name-mismatch "$rel" "name '${token#name=}' should be '$expected'"
        fi ;;
      desc=missing|desc=empty)
        [ "$mode" = "required" ] && err fm-description-missing "$rel" "frontmatter has no non-empty 'description'" ;;
      desc=multiline)
        err fm-description-multiline "$rel" "multi-line description must be a block scalar (description: >-)" ;;
      desc=colon)
        err fm-description-colon "$rel" "plain description contains ': ' — use a block scalar (description: >-)" ;;
    esac
  done < <(parse_frontmatter "$file")
  return 0
}

# check_positional <file> <rel> — "$<digit>" not escaped by exactly one backslash
# ("\\$1" still expands, so only a single backslash counts as an escape).
check_positional() {
  local file="$1" rel="$2" hit
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    err positional-var "$rel:${hit%%:*}" "positional variable in body: ${hit#*:}"
  done < <(awk '
    {
      rest = $0; pos = 0
      while ((i = index(rest, "$")) > 0) {
        pos += i
        if (substr(rest, i + 1, 1) ~ /[0-9]/) {
          n = 0
          for (j = pos - 1; j >= 1 && substr($0, j, 1) == "\\"; j--) n++
          if (n != 1) { printf "%d:%s\n", NR, $0; break }
        }
        rest = substr(rest, i + 1)
      }
    }
  ' "$file")
  return 0
}

check_prefix() {  # <name> <rel>
  case "$1" in
    kaizen-*) ;;
    *) err prefix "$2" "name must start with 'kaizen-'" ;;
  esac
}

# --- skills ---

for dir in "$ROOT"/.claude/skills/*/; do
  [ -d "$dir" ] || continue
  N_SKILLS=$((N_SKILLS + 1))
  name="$(basename "$dir")"
  rel=".claude/skills/$name"
  check_prefix "$name" "$rel"
  if [ ! -f "$dir/SKILL.md" ]; then
    err skill-no-skillmd "$rel" "skill directory has no SKILL.md"
    continue
  fi
  check_frontmatter "$dir/SKILL.md" "$rel/SKILL.md" "$name" required
  check_positional "$dir/SKILL.md" "$rel/SKILL.md"
done

# --- commands ---

for file in "$ROOT"/.claude/commands/*.md; do
  [ -f "$file" ] || continue
  N_COMMANDS=$((N_COMMANDS + 1))
  name="$(basename "$file")"
  rel=".claude/commands/$name"
  check_prefix "$name" "$rel"
  check_frontmatter "$file" "$rel" "${name%.md}" optional
  check_positional "$file" "$rel"
done

# --- agents ---

for file in "$ROOT"/.claude/agents/*.md; do
  [ -f "$file" ] || continue
  N_AGENTS=$((N_AGENTS + 1))
  name="$(basename "$file")"
  rel=".claude/agents/$name"
  check_prefix "$name" "$rel"
  check_frontmatter "$file" "$rel" "${name%.md}" required
done

# Zero targets means the directory layout was not understood — not "clean".
if [ $((N_SKILLS + N_COMMANDS + N_AGENTS)) -eq 0 ]; then
  echo "Error: no skills, commands, or agents found under $ROOT/.claude" >&2
  exit 2
fi

# --- file length (every file under the framework directory) ---

N_FILES=0
while IFS= read -r file; do
  N_FILES=$((N_FILES + 1))
  lines="$(wc -l < "$file")"
  case "$file" in
    *.sh|*.py) limit="$MAX_SCRIPT_LINES" ;;
    *)         limit="$MAX_LINES" ;;
  esac
  if [ "$lines" -gt "$limit" ]; then
    err max-lines "${file#"$ROOT"/}" "$((lines)) lines (limit $limit) — split the file"
  fi
done < <(find "$ROOT" -type f | sort)

# --- referenced framework/bin/ scripts exist ---

while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file="${hit%%:*}"
  rest="${hit#*:}"
  lineno="${rest%%:*}"
  ref="${rest#*:}"
  script="${ref#framework/bin/}"
  # Globs (kaizen-*.sh) and sentence-final dots are not script names.
  case "$script" in *'*'*) continue ;; esac
  while [ "${script%.}" != "$script" ]; do script="${script%.}"; done
  [ -n "$script" ] || continue
  if [ ! -f "$ROOT/bin/$script" ]; then
    err bin-ref "${file#"$ROOT"/}:$lineno" "framework/bin/$script does not exist"
  fi
done < <(find "$ROOT/.claude" -type f -name '*.md' -exec grep -HnoE 'framework/bin/[A-Za-z0-9._*-]+' {} + | sort -u)

# --- no sweeping git add / pathless commit in a code fence ---

while IFS= read -r file; do
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    err sweeping-commit "${file#"$ROOT"/}:${hit%%:*}" "${hit#*:}"
  done < <(awk '
    function check(cmd, n) {
      if (cmd ~ /^[ \t]*#/) return
      if (cmd !~ /git[ \t]/) return
      if (cmd ~ /[ \t]add[ \t]+-A/ || cmd ~ /[ \t]add[ \t]+--all/ || cmd ~ /[ \t]add[ \t]+\.[ \t]*$/ || cmd ~ /[ \t]add[ \t]+\.[ \t]/) {
        printf "%d:git add that stages everything — pass the files to kaizen-knowledge-commit.sh\n", n
        return
      }
      if (cmd ~ /git[ \t]+-C[ \t]/ && cmd ~ /[ \t]commit[ \t]/ && cmd !~ /[ \t]--[ \t]/) {
        printf "%d:git -C <dir> commit without -- <paths> — use kaizen-knowledge-commit.sh\n", n
      }
    }
    /^[ \t]*(```|~~~)/ { in_fence = !in_fence; buf = ""; next }
    !in_fence { next }
    {
      line = $0
      if (buf == "") start = NR
      if (line ~ /\\[ \t]*$/) { sub(/\\[ \t]*$/, " ", line); buf = buf line; next }
      check(buf line, start)
      buf = ""
    }
  ' "$file")
done < <(find "$ROOT/.claude" -type f -name '*.md' | sort)

# --- summary ---

echo "lint: $N_SKILLS skill(s), $N_COMMANDS command(s), $N_AGENTS agent(s), $N_FILES file(s) checked — $VIOLATIONS violation(s)"
if [ "$VIOLATIONS" -gt 0 ]; then
  exit 1
fi
exit 0
