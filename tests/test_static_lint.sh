#!/bin/bash
# Tests for tests/lint_framework.sh (static lint of the distributed framework)
# Usage: bash tests/test_static_lint.sh
#
# 1. The real framework/ must be clean (this is the gate run by run_all.sh).
# 2. Each rule has a fixture that violates only that rule and must turn red.

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

LINT="$KAIZEN_CLI_DIR/tests/lint_framework.sh"

# --- Fixture ---

# A minimal framework tree that passes every rule. Each test mutates one thing.
setup_lint_env() {
  setup_test_env "$1"
  FX="$TEST_HOME/framework"
  mkdir -p "$FX/.claude/skills/kaizen-alpha" "$FX/.claude/commands" "$FX/.claude/agents" "$FX/bin"

  cat > "$FX/.claude/skills/kaizen-alpha/SKILL.md" <<'EOF'
---
name: kaizen-alpha
description: >-
  Applied when editing files. Usage: "/kaizen-alpha"
  Second line: with a colon, which is fine inside a block scalar.
---

# kaizen-alpha

Run `bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-tool.sh"` and read the output.
EOF

  # Supporting file: read with the Read tool, so positional variables are allowed.
  cat > "$FX/.claude/skills/kaizen-alpha/REFERENCE.md" <<'EOF'
# Reference

    awk '{print $1}' file
EOF

  # Commands carry no frontmatter in this project.
  cat > "$FX/.claude/commands/kaizen-cmd.md" <<'EOF'
# A command

Target: `knowledge/$ARGUMENTS` (first of `$ARGUMENTS[0]`).
Scripts live in `framework/bin/` and match `framework/bin/kaizen-*.sh`.
EOF

  cat > "$FX/.claude/agents/kaizen-agent.md" <<'EOF'
---
name: kaizen-agent
model: sonnet
description: Audits files and reports findings
tools: Read, Grep, Bash
---

# kaizen-agent
EOF

  echo '#!/bin/bash' > "$FX/bin/kaizen-tool.sh"
}

# run_lint — sets LINT_OUTPUT and LINT_RC
run_lint() {
  LINT_RC=0
  LINT_OUTPUT=$(bash "$LINT" "$FX" 2>&1) || LINT_RC=$?
}

# expect_only <rule> <path fragment> — exit 1, the rule is reported at the path,
# and it is the only violation (so the fixture isolates one rule).
expect_only() {
  local rule="$1" where="$2" ok=0
  run_lint
  if [ "$LINT_RC" -ne 1 ]; then
    echo "  FAIL: exit code should be 1, got $LINT_RC"
    ok=1
  fi
  # Two steps instead of a pipe: under pipefail, `grep | grep -q` can fail
  # spuriously when the reader exits first.
  local rule_lines
  rule_lines=$(grep -F "ERROR [$rule] " <<<"$LINT_OUTPUT" || true)
  if ! grep -qF "$where" <<<"$rule_lines"; then
    echo "  FAIL: expected [$rule] at '$where'"
    ok=1
  fi
  assert_output_contains "$LINT_OUTPUT" "— 1 violation(s)" \
    "exactly one violation expected" || ok=1
  if [ "$ok" -ne 0 ]; then
    echo "$LINT_OUTPUT" | sed 's/^/    | /'
  fi
  return "$ok"
}

expect_clean() {
  local ok=0
  run_lint
  if [ "$LINT_RC" -ne 0 ]; then
    echo "  FAIL: exit code should be 0, got $LINT_RC"
    echo "$LINT_OUTPUT" | sed 's/^/    | /'
    ok=1
  fi
  assert_output_contains "$LINT_OUTPUT" "— 0 violation(s)" "no violations expected" || ok=1
  return "$ok"
}

# run_case <test name> <mutation function> <expectation...>
run_case() {
  local test_name="$1" mutate="$2"
  shift 2
  setup_lint_env "$test_name"
  local ok=0
  "$mutate"
  "$@" || ok=1
  record_result "$test_name" "$ok"
  teardown_test_env
}

no_mutation() { :; }

# --- Real framework ---

test_real_framework_clean() {
  local test_name="real framework/ passes the lint"
  setup_test_env "$test_name"
  local ok=0

  local output rc=0
  output=$(bash "$LINT" 2>&1) || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  FAIL: framework/ has lint violations (exit $rc)"
    echo "$output" | sed 's/^/    | /'
    ok=1
  fi
  # Guard against a vacuous pass: the lint must have found something to check.
  if grep -qE 'lint: 0 skill\(s\)|, 0 command\(s\)|, 0 agent\(s\)' <<<"$output"; then
    echo "  FAIL: lint found no skills, commands, or agents: $output"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Frontmatter mutations ---

mut_fm_missing() {
  printf '# kaizen-alpha\n\nNo frontmatter here.\n' > "$FX/.claude/skills/kaizen-alpha/SKILL.md"
}

mut_fm_unclosed() {
  cat > "$FX/.claude/agents/kaizen-agent.md" <<'EOF'
---
name: kaizen-agent
description: Audits files and reports findings

# kaizen-agent
EOF
}

mut_name_missing() {
  cat > "$FX/.claude/agents/kaizen-agent.md" <<'EOF'
---
description: Audits files and reports findings
---
EOF
}

mut_name_empty() {
  cat > "$FX/.claude/agents/kaizen-agent.md" <<'EOF'
---
name:
description: Audits files and reports findings
---
EOF
}

mut_name_mismatch_skill() {
  cat > "$FX/.claude/skills/kaizen-alpha/SKILL.md" <<'EOF'
---
name: kaizen-renamed
description: Applied when editing files
---
EOF
}

mut_name_mismatch_agent() {
  cat > "$FX/.claude/agents/kaizen-agent.md" <<'EOF'
---
name: kaizen-other
description: Audits files and reports findings
---
EOF
}

mut_desc_missing() {
  cat > "$FX/.claude/agents/kaizen-agent.md" <<'EOF'
---
name: kaizen-agent
tools: Read
---
EOF
}

mut_desc_empty_block() {
  cat > "$FX/.claude/agents/kaizen-agent.md" <<'EOF'
---
name: kaizen-agent
description: >-
tools: Read
---
EOF
}

mut_desc_multiline_plain() {
  cat > "$FX/.claude/skills/kaizen-alpha/SKILL.md" <<'EOF'
---
name: kaizen-alpha
description: Applied when editing files
  and continued on a second line
---
EOF
}

mut_desc_colon() {
  cat > "$FX/.claude/agents/kaizen-agent.md" <<'EOF'
---
name: kaizen-agent
description: Audits files. Usage: run it after edits
---
EOF
}

mut_desc_quoted_colon() {
  cat > "$FX/.claude/agents/kaizen-agent.md" <<'EOF'
---
name: kaizen-agent
description: "Audits files. Usage: run it after edits"
---
EOF
}

mut_command_fm_unclosed() {
  cat > "$FX/.claude/commands/kaizen-cmd.md" <<'EOF'
---
description: A command

# A command
EOF
}

mut_command_fm_colon() {
  cat > "$FX/.claude/commands/kaizen-cmd.md" <<'EOF'
---
description: A command. Usage: /kaizen-cmd
---

# A command
EOF
}

# --- Positional-variable mutations ---

mut_positional_command() {
  cat >> "$FX/.claude/commands/kaizen-cmd.md" <<'EOF'

```bash
git log --oneline | awk '{print $1}'
```
EOF
}

mut_positional_skill() {
  cat >> "$FX/.claude/skills/kaizen-alpha/SKILL.md" <<'EOF'

The first argument is $0 and the price is unrelated.
EOF
}

mut_positional_double_backslash() {
  # A doubled backslash does not escape: "$1" is still expanded.
  cat >> "$FX/.claude/commands/kaizen-cmd.md" <<'EOF'

Literal: \\$1
EOF
}

mut_positional_escaped() {
  cat >> "$FX/.claude/commands/kaizen-cmd.md" <<'EOF'

Costs \$1.00 per run. See also $ARGUMENTS, $HOME and ${CLAUDE_SKILL_DIR}.
EOF
}

# --- Distribution-convention mutations ---

mut_prefix_skill() {
  mkdir -p "$FX/.claude/skills/my-skill"
  cat > "$FX/.claude/skills/my-skill/SKILL.md" <<'EOF'
---
name: my-skill
description: A skill without the prefix
---
EOF
}

mut_prefix_command() {
  echo "# Deploy" > "$FX/.claude/commands/deploy.md"
}

mut_prefix_agent() {
  cat > "$FX/.claude/agents/reviewer.md" <<'EOF'
---
name: reviewer
description: An agent without the prefix
---
EOF
}

mut_skill_no_skillmd() {
  mkdir -p "$FX/.claude/skills/kaizen-empty"
  echo "# notes" > "$FX/.claude/skills/kaizen-empty/NOTES.md"
}

mut_max_lines() {
  local i
  for i in $(seq 1 801); do echo "line $i"; done > "$FX/bin/kaizen-long.sh"
}

mut_exactly_max_lines() {
  local i
  for i in $(seq 1 800); do echo "line $i"; done > "$FX/bin/kaizen-long.sh"
}

mut_bin_ref_missing() {
  cat >> "$FX/.claude/agents/kaizen-agent.md" <<'EOF'

Run `bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-gone.sh" --all`.
EOF
}

mut_bin_ref_sentence_end() {
  # A sentence-final dot is not part of the script name.
  cat >> "$FX/.claude/agents/kaizen-agent.md" <<'EOF'

The check lives in framework/bin/kaizen-tool.sh.
EOF
}

# --- Usage / cannot determine ---

test_lint_nothing_to_lint() {
  local test_name="exit 2 when there is nothing to lint"
  setup_lint_env "$test_name"
  local ok=0

  # Not a framework directory at all
  LINT_RC=0
  LINT_OUTPUT=$(bash "$LINT" "$TEST_HOME/nowhere" 2>&1) || LINT_RC=$?
  if [ "$LINT_RC" -ne 2 ]; then
    echo "  FAIL: missing directory should exit 2, got $LINT_RC"
    ok=1
  fi

  # A .claude/ with no skills, commands, or agents must not read as clean
  rm -r "$FX/.claude/skills" "$FX/.claude/commands" "$FX/.claude/agents"
  run_lint
  if [ "$LINT_RC" -ne 2 ]; then
    echo "  FAIL: empty .claude/ should exit 2, got $LINT_RC"
    ok=1
  fi
  assert_output_not_contains "$LINT_OUTPUT" "0 violation(s)" \
    "an empty tree must not report a clean result" || ok=1

  # Extra arguments
  LINT_RC=0
  LINT_OUTPUT=$(bash "$LINT" "$FX" extra 2>&1) || LINT_RC=$?
  if [ "$LINT_RC" -ne 2 ]; then
    echo "  FAIL: extra arguments should exit 2, got $LINT_RC"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run all tests ---

echo "=== lint_framework.sh tests ==="
echo ""

test_real_framework_clean
run_case "fixture: valid tree is clean" no_mutation expect_clean

run_case "fm-missing: SKILL.md without frontmatter" \
  mut_fm_missing expect_only fm-missing "skills/kaizen-alpha/SKILL.md"
run_case "fm-unclosed: agent frontmatter never closed" \
  mut_fm_unclosed expect_only fm-unclosed "agents/kaizen-agent.md"
run_case "fm-name-missing: no name key" \
  mut_name_missing expect_only fm-name-missing "agents/kaizen-agent.md"
run_case "fm-name-missing: empty name" \
  mut_name_empty expect_only fm-name-missing "agents/kaizen-agent.md"
run_case "fm-name-mismatch: skill name differs from directory" \
  mut_name_mismatch_skill expect_only fm-name-mismatch "skills/kaizen-alpha/SKILL.md"
run_case "fm-name-mismatch: agent name differs from file" \
  mut_name_mismatch_agent expect_only fm-name-mismatch "agents/kaizen-agent.md"
run_case "fm-description-missing: no description key" \
  mut_desc_missing expect_only fm-description-missing "agents/kaizen-agent.md"
run_case "fm-description-missing: block scalar with no content" \
  mut_desc_empty_block expect_only fm-description-missing "agents/kaizen-agent.md"
run_case "fm-description-multiline: plain scalar spans lines" \
  mut_desc_multiline_plain expect_only fm-description-multiline "skills/kaizen-alpha/SKILL.md"
run_case "fm-description-colon: plain scalar contains ': '" \
  mut_desc_colon expect_only fm-description-colon "agents/kaizen-agent.md"
run_case "fm-description-colon: quoted scalar with ': ' is allowed" \
  mut_desc_quoted_colon expect_clean
run_case "fm-unclosed: command frontmatter never closed" \
  mut_command_fm_unclosed expect_only fm-unclosed "commands/kaizen-cmd.md"
run_case "fm-description-colon: applies to a command that has frontmatter" \
  mut_command_fm_colon expect_only fm-description-colon "commands/kaizen-cmd.md"

run_case "positional-var: \$1 inside a code fence of a command" \
  mut_positional_command expect_only positional-var "commands/kaizen-cmd.md:"
run_case "positional-var: \$0 in SKILL.md prose" \
  mut_positional_skill expect_only positional-var "skills/kaizen-alpha/SKILL.md:"
run_case "positional-var: doubled backslash does not escape" \
  mut_positional_double_backslash expect_only positional-var "commands/kaizen-cmd.md:"
run_case "positional-var: \\\$1 escape, \$ARGUMENTS and \${VAR} are allowed" \
  mut_positional_escaped expect_clean

run_case "prefix: skill without kaizen-" \
  mut_prefix_skill expect_only prefix "skills/my-skill"
run_case "prefix: command without kaizen-" \
  mut_prefix_command expect_only prefix "commands/deploy.md"
run_case "prefix: agent without kaizen-" \
  mut_prefix_agent expect_only prefix "agents/reviewer.md"
run_case "skill-no-skillmd: skill directory without SKILL.md" \
  mut_skill_no_skillmd expect_only skill-no-skillmd "skills/kaizen-empty"
run_case "max-lines: 801-line file" \
  mut_max_lines expect_only max-lines "bin/kaizen-long.sh"
run_case "max-lines: exactly 800 lines is allowed" \
  mut_exactly_max_lines expect_clean
run_case "bin-ref: referenced script does not exist" \
  mut_bin_ref_missing expect_only bin-ref "agents/kaizen-agent.md:"
run_case "bin-ref: sentence-final dot is not part of the name" \
  mut_bin_ref_sentence_end expect_clean

test_lint_nothing_to_lint

print_results
