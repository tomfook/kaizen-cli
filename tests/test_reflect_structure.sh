#!/bin/bash
# Structural tests for the reflect-learning pipeline
# (skills/kaizen-reflect-learning/{SKILL.md,CRITERIA.md}, the reflector and the
# verifier agent definitions).
# Usage: bash tests/test_reflect_structure.sh
#
# The pipeline is prose, so nothing fails at runtime when its parts drift apart:
# a subagent that reads the main agent's flow still returns a verdict, and a
# verifier fed the reflector's summary still "verifies". These tests pin the
# information flow instead:
#   - the subagents read the criteria file and nothing else of the skill
#   - the verifier is given the main agent's fact payload verbatim
#   - criteria and flow each live in one file
#   - every section the three files point to in CRITERIA.md exists
#   - the criteria say what a record is for, and no file falls back to "a failure
#     is always recorded"
#   - routing (the four choices, the lane that is not written at once) stays in
#     the main flow, out of what the subagents read

source "$(cd "$(dirname "$0")" && pwd)/helper.sh"

DIST="$KAIZEN_CLI_DIR/framework/.claude"
SKILL_DIR="$DIST/skills/kaizen-reflect-learning"
SKILL_MD="$SKILL_DIR/SKILL.md"
CRITERIA_MD="$SKILL_DIR/CRITERIA.md"
REFLECTOR="$DIST/agents/kaizen-learning-reflector.md"
VERIFIER="$DIST/agents/kaizen-learning-verifier.md"
KAIZEN_INIT="$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh"
CRITERIA_PATH=".claude/skills/kaizen-reflect-learning/CRITERIA.md"

# --- Helpers ---

# assert_file_lacks <file> <fixed string> [message]
assert_file_lacks() {
  local file="$1" pattern="$2"
  local msg="${3:-$(basename "$file") should not contain '$pattern'}"
  # A missing file must not read as "does not contain".
  if [ ! -f "$file" ]; then
    echo "  FAIL: file does not exist: $file"
    return 1
  fi
  if grep -qF -- "$pattern" "$file"; then
    echo "  FAIL: $msg"
    grep -nF -- "$pattern" "$file" | sed 's/^/    | /'
    return 1
  fi
}

# assert_has_heading <file> <heading line>
assert_has_heading() {
  local file="$1" heading="$2"
  if ! grep -qxF -- "$heading" "$file"; then
    echo "  FAIL: $(basename "$file") should have the heading '$heading'"
    return 1
  fi
}

# assert_no_heading <file> <heading line>
assert_no_heading() {
  local file="$1" heading="$2"
  if grep -qxF -- "$heading" "$file"; then
    echo "  FAIL: $(basename "$file") should not have the heading '$heading'"
    return 1
  fi
}

# Headings of CRITERIA.md that the flow and the agents point to by name.
criteria_headings() {
  cat <<'EOF'
## 何を残すか
## 抽出カテゴリ（9カテゴリ）
## データ主張を含む知見の粒度分離
## ファイル反映のルール
## knowledge/ の検索方法
## 簡潔性の原則
EOF
}

# --- Test 1: layout ---

test_layout() {
  local test_name="reflect: a skill directory with the flow and the criteria, no command of the same name"
  setup_test_env "$test_name"
  local ok=0

  assert_file_exists "$SKILL_MD" || ok=1
  assert_file_exists "$CRITERIA_MD" || ok=1
  # A command and a skill of the same name would both register /kaizen-reflect-learning.
  assert_file_not_exists "$DIST/commands/kaizen-reflect-learning.md" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 2: the subagents read CRITERIA.md only ---

test_agents_read_criteria_only() {
  local test_name="reflect: reflector and verifier read CRITERIA.md, not the main flow"
  setup_test_env "$test_name"
  local ok=0 agent paths

  for agent in "$REFLECTOR" "$VERIFIER"; do
    assert_file_contains "$agent" "$CRITERIA_PATH" \
      "$(basename "$agent") should name the criteria file" || ok=1
    assert_file_lacks "$agent" ".claude/commands/kaizen-reflect-learning" || ok=1
    assert_file_lacks "$agent" "コマンドファイル" || ok=1
    assert_file_contains "$agent" '`SKILL.md` は読まない' \
      "$(basename "$agent") should say that the main flow is not read" || ok=1
    assert_file_contains "$agent" "CRITERIA.md を読めない場合は判定しない" \
      "$(basename "$agent") should stop when the criteria cannot be read" || ok=1

    # The only file of the skill directory that an agent names by path is CRITERIA.md.
    paths="$(grep -oE 'skills/kaizen-reflect-learning/[A-Za-z0-9_.-]+' "$agent" | sort -u)"
    if [ "$paths" != "skills/kaizen-reflect-learning/CRITERIA.md" ]; then
      echo "  FAIL: $(basename "$agent") should point into the skill directory at CRITERIA.md only, got:"
      echo "$paths" | sed 's/^/    | /'
      ok=1
    fi
  done

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 3: the reflector works from the payload and does not relay it ---

test_reflector_payload() {
  local test_name="reflect: reflector scans the fact payload and returns no summary of it"
  setup_test_env "$test_name"
  local ok=0

  assert_file_lacks "$REFLECTOR" "会話履歴のスキャン" || ok=1
  assert_file_contains "$REFLECTOR" "### 2. 事実ペイロードのスキャン" || ok=1
  assert_file_contains "$REFLECTOR" "ペイロード欠落の検知" || ok=1
  assert_file_contains "$REFLECTOR" "ペイロードの欠落項目:" \
    "the hand-over should have a slot for missing payload items" || ok=1
  # The old return format carried a "facts" section that the main agent relayed.
  assert_file_lacks "$REFLECTOR" "### 事実情報" || ok=1
  assert_file_lacks "$REFLECTOR" "kaizen-learning-verifier入力用" || ok=1
  assert_file_contains "$REFLECTOR" "ペイロードの再要約は返さない" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 4: the verifier's input is the payload verbatim ---

test_verifier_input() {
  local test_name="reflect: verifier input is the main agent's payload verbatim"
  setup_test_env "$test_name"
  local ok=0

  assert_file_contains "$VERIFIER" "**事実ペイロードの原文**" || ok=1
  assert_file_contains "$VERIFIER" "reflector による再要約ではない" || ok=1
  assert_file_lacks "$VERIFIER" "reflectorが収集したもの" || ok=1
  assert_file_lacks "$VERIFIER" "から抽出）" \
    "the verifier should read the criteria itself, not receive an excerpt" || ok=1

  # The flow must hand over the same thing the verifier expects.
  assert_file_contains "$SKILL_MD" "事実ペイロードの**原文**" || ok=1
  assert_file_contains "$SKILL_MD" "spawn 後に判明した事実" || ok=1
  assert_file_contains "$VERIFIER" "spawn 後に判明した事実" || ok=1
  # ... and must not go back to relaying the reflector's wording.
  assert_file_lacks "$SKILL_MD" "「事実情報」セクション" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 5: criteria and flow each live in one file ---

test_criteria_flow_split() {
  local test_name="reflect: criteria live in CRITERIA.md, the flow in SKILL.md"
  setup_test_env "$test_name"
  local ok=0 heading

  while IFS= read -r heading; do
    assert_has_heading "$CRITERIA_MD" "$heading" || ok=1
    assert_no_heading "$SKILL_MD" "$heading" || ok=1
  done < <(criteria_headings)

  # Main-only material: reading it would pull the verifier toward the main
  # agent's routing instead of an independent verdict.
  assert_file_lacks "$CRITERIA_MD" "代替先推奨マトリクス" || ok=1
  assert_file_lacks "$CRITERIA_MD" "### Step" || ok=1
  assert_file_lacks "$CRITERIA_MD" "kaizen-knowledge-commit.sh" || ok=1
  assert_file_contains "$SKILL_MD" "#### 代替先推奨マトリクス" || ok=1
  assert_file_contains "$SKILL_MD" "### Step 9:" || ok=1

  # The payload spec is the contract between the three files.
  assert_file_contains "$SKILL_MD" "#### 必須ペイロード（5項目）" || ok=1
  assert_file_contains "$REFLECTOR" "必須5項目" || ok=1
  assert_file_contains "$VERIFIER" "必須5項目" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 6: every section reference into CRITERIA.md resolves ---

test_section_references() {
  local test_name="reflect: section references into CRITERIA.md resolve"
  setup_test_env "$test_name"
  local ok=0 out rc=0 n resolved

  if ! command -v python3 >/dev/null 2>&1; then
    echo "  (skipped: python3 not available)"
    record_result "$test_name" 0
    teardown_test_env
    return
  fi

  # An empty knowledge directory: these files must not depend on the developer's own.
  mkdir -p "$TEST_HOME/empty-knowledge"
  out=$(python3 "$KAIZEN_CLI_DIR/framework/bin/kaizen-check-refs.py" \
    --project "$KAIZEN_CLI_DIR/framework" --knowledge "$TEST_HOME/empty-knowledge" \
    .claude/skills/kaizen-reflect-learning/SKILL.md \
    .claude/skills/kaizen-reflect-learning/CRITERIA.md \
    .claude/agents/kaizen-learning-reflector.md \
    .claude/agents/kaizen-learning-verifier.md 2>&1) || rc=$?

  if [ "$rc" -ne 0 ]; then
    echo "  FAIL: kaizen-check-refs.py exit code should be 0, got $rc"
    echo "$out" | sed 's/^/    | /'
    ok=1
  fi
  assert_output_contains "$out" "scanned 4 file(s)" "all four files should be scanned" || ok=1
  assert_output_contains "$out" "MISS 0" || ok=1

  # "No broken reference" must not be reached by extracting nothing.
  n="$(grep -oF -- "\`$CRITERIA_PATH § " "$REFLECTOR" "$VERIFIER" "$SKILL_MD" | wc -l | tr -d ' ')"
  if [ "$n" -lt 8 ]; then
    echo "  FAIL: expected at least 8 section references into CRITERIA.md, found $n"
    ok=1
  fi
  resolved="$(echo "$out" | sed -n 's/.*references OK \([0-9][0-9]*\) .*/\1/p' | tail -1)"
  if [ -z "$resolved" ] || [ "$resolved" -lt "$n" ]; then
    echo "  FAIL: $n references into CRITERIA.md are written, but only '${resolved:-none}' were resolved"
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 7: a project linked before the move is repaired by sync-links ---

test_migration_from_command() {
  local test_name="reflect: sync-links replaces the old command link with the skill directory"
  setup_test_env "$test_name"
  local ok=0 out rc=0
  local project="$TEST_HOME/project"

  # A project initialized when reflect-learning was a command.
  mkdir -p "$project/.claude/commands"
  ln -s "$DIST/commands/kaizen-reflect-learning.md" \
    "$project/.claude/commands/kaizen-reflect-learning.md"

  out=$(bash "$KAIZEN_INIT" check-links "$project" 2>&1) || rc=$?
  if [ "$rc" -ne 1 ]; then
    echo "  FAIL: check-links should report drift (exit 1), got $rc"
    ok=1
  fi
  assert_output_contains "$out" "dangling: commands/kaizen-reflect-learning.md" || ok=1
  assert_output_contains "$out" "missing: skills/kaizen-reflect-learning" || ok=1

  rc=0
  out=$(bash "$KAIZEN_INIT" sync-links "$project" 2>&1) || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  FAIL: sync-links should succeed, got $rc"
    echo "$out" | sed 's/^/    | /'
    ok=1
  fi
  assert_output_contains "$out" "removed: commands/kaizen-reflect-learning.md" || ok=1
  assert_output_contains "$out" "linked: skills/kaizen-reflect-learning" || ok=1

  if [ -e "$project/.claude/commands/kaizen-reflect-learning.md" ] || \
     [ -L "$project/.claude/commands/kaizen-reflect-learning.md" ]; then
    echo "  FAIL: the old command link should be gone"
    ok=1
  fi
  # The path the agents read must resolve from inside the project.
  assert_file_contains "$project/$CRITERIA_PATH" "## 何を残すか" \
    "CRITERIA.md should be readable through the project link" || ok=1
  assert_file_exists "$project/.claude/skills/kaizen-reflect-learning/SKILL.md" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 8: the criteria state a purpose, not a rule keyed on failure ---

test_purpose_criteria() {
  local test_name="reflect: the criteria say what a record is for, in all three files"
  setup_test_env "$test_name"
  local ok=0 f hits

  assert_file_contains "$CRITERIA_MD" "これが書いてあれば、次は時間を失わない・誤らない" || ok=1
  assert_file_contains "$CRITERIA_MD" "それだけでは採用の理由にしない" || ok=1
  # What the old condition 3 guarded stays: written already, and it still went wrong.
  assert_file_contains "$CRITERIA_MD" "「記載済みだから不要」で終えない" || ok=1
  assert_file_contains "$VERIFIER" "「既存ゆえ記録不要」の差し戻し" || ok=1
  # The categories are a lookup table. "Check all of them" is the fixed rule again.
  assert_file_contains "$CRITERIA_MD" "全カテゴリを埋めるチェックリストではない" || ok=1
  assert_file_lacks "$CRITERIA_MD" "漏れなく確認" || ok=1
  assert_file_lacks "$REFLECTOR" "漏れなくスキャン" || ok=1

  for f in "$REFLECTOR" "$VERIFIER"; do
    assert_file_contains "$f" "\`$CRITERIA_PATH § 何を残すか\`" \
      "$(basename "$f") should point at the purpose section" || ok=1
  done
  # The reflector accounts for every failure and correction, without having to adopt it.
  assert_file_contains "$REFLECTOR" "通過か不通過のどちらかに必ず置く" || ok=1
  assert_file_contains "$REFLECTOR" "残す理由:" || ok=1
  assert_file_contains "$REFLECTOR" "確度:" || ok=1
  assert_file_lacks "$REFLECTOR" "通過条件:" || ok=1
  # The reflector's reason is reasoning: it does not go to the verifier.
  assert_file_contains "$SKILL_MD" "通過とした理由（「残す理由」「確度」）" || ok=1

  # No distributed file or public doc still describes the fixed rule.
  # (CRITERIA.md names the old section once, to say what replaced it.)
  hits="$(grep -rnE '条件 ?3|無条件採用|無条件で採用されます|禁止フィルタ|unconditionally captured|auto-approved|[Gg]eneralization ([Tt]est|[Cc]riteria)|一般化条件' \
    "$KAIZEN_CLI_DIR/framework" "$KAIZEN_CLI_DIR"/docs/*.md \
    "$KAIZEN_CLI_DIR/README.md" "$KAIZEN_CLI_DIR/README.ja.md" 2>/dev/null \
    | grep -v '/CRITERIA.md:.*この節は以前「一般化テスト」' || true)"
  if [ -n "$hits" ]; then
    echo "  FAIL: the fixed rule is still described in:"
    echo "$hits" | sed 's/^/    | /'
    ok=1
  fi
  hits="$(grep -rnF '一般化テスト' "$KAIZEN_CLI_DIR/framework" "$KAIZEN_CLI_DIR"/docs/*.md \
    | grep -v '/CRITERIA.md:.*この節は以前「一般化テスト」' || true)"
  if [ -n "$hits" ]; then
    echo "  FAIL: the old section name is still used in:"
    echo "$hits" | sed 's/^/    | /'
    ok=1
  fi

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 9: four choices; the lane that is not written at once ---

test_deliberate_lane() {
  local test_name="reflect: four choices, and the deliberate lane goes to NEXT_STEPS through update-docs"
  setup_test_env "$test_name"
  local ok=0 f lane

  assert_file_contains "$SKILL_MD" "④ 要熟考" || ok=1
  assert_file_contains "$SKILL_MD" "の4択で提示する" || ok=1
  assert_file_lacks "$SKILL_MD" "の3択で提示する" || ok=1
  assert_file_contains "$SKILL_MD" "| **要熟考** ＝" "the routing table should have the lane" || ok=1
  assert_file_contains "$SKILL_MD" "| **判定一致（通過）／反映先だけが食い違う**" || ok=1
  assert_file_contains "$SKILL_MD" "**verifier が持ち帰った新しい事実**" || ok=1

  # Where the lane leads, and who writes there.
  lane="$(bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-extract-section.sh" "$SKILL_MD" '要熟考の行き先' 2>/dev/null)" || {
    echo "  FAIL: SKILL.md should have the section '要熟考の行き先'"
    lane=""
    ok=1
  }
  assert_output_contains "$lane" 'docs/NEXT_STEPS.md' || ok=1
  assert_output_contains "$lane" '/kaizen-update-docs' || ok=1
  assert_output_contains "$lane" '書き込まない' "reflect itself must not write the project's NEXT_STEPS" || ok=1
  assert_output_contains "$lane" '迷ったら要熟考に倒す' || ok=1
  assert_file_contains "$SKILL_MD" "| 要熟考 | 起票文を示し、\`/kaizen-update-docs\` を案内する" || ok=1
  # update-docs is the writer of NEXT_STEPS: it must know this source.
  assert_file_contains "$DIST/commands/kaizen-update-docs.md" "要熟考" \
    "kaizen-update-docs should pick up what reflect set aside" || ok=1

  # Routing is the main agent's. A subagent that reads it judges toward it.
  for f in "$CRITERIA_MD" "$REFLECTOR" "$VERIFIER"; do
    assert_file_lacks "$f" "要熟考" || ok=1
    assert_file_lacks "$f" "NEXT_STEPS" || ok=1
  done
  # The verifier supplies the signal the lane is keyed on, in its own words.
  assert_file_contains "$VERIFIER" "記述の追加では止まらない" || ok=1
  assert_file_contains "$VERIFIER" "反映先の候補:" || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Test 10: causal claims, counts, and size ---

test_claims_and_size() {
  local test_name="reflect: causal claims and counts are separated; size is no reason to drop or defer"
  setup_test_env "$test_name"
  local ok=0 fix

  assert_has_heading "$CRITERIA_MD" "### 因果の主張にも同じ分離が要る" || ok=1
  assert_has_heading "$CRITERIA_MD" "### 回数・時間・件数は数え直す" || ok=1
  assert_file_contains "$CRITERIA_MD" "1 つだけを変えた再現を 1 回" || ok=1
  assert_file_contains "$SKILL_MD" "**因果の主張と数も、同じ節に従う**" || ok=1
  assert_file_contains "$SKILL_MD" "**未検証の主張への対応**" || ok=1
  assert_file_contains "$SKILL_MD" "棄却の経緯ごと Step 5 で報告する" || ok=1
  assert_file_contains "$REFLECTOR" "未検証の派生主張・因果:" || ok=1
  assert_file_contains "$VERIFIER" "### 未検証の主張（因果・数）" || ok=1
  assert_file_contains "$VERIFIER" "未検証の主張: N件" || ok=1

  # Size: compress wording, keep content, never defer.
  assert_file_lacks "$CRITERIA_MD" "ファイルサイズ管理（800行以内）を遵守" || ok=1
  assert_file_contains "$CRITERIA_MD" "| 圧縮してよい（表現） | 削ってはいけない（内容） |" || ok=1
  assert_file_contains "$CRITERIA_MD" "**サイズを反映先の決定理由にしない**" || ok=1
  assert_file_contains "$CRITERIA_MD" "**追記先の節の、既存の規約と衝突しないか確かめる**" || ok=1
  assert_file_contains "$REFLECTOR" "反映を保留する案は出さない" || ok=1
  assert_file_contains "$SKILL_MD" "**書き込む前に、追記先の節を通読する**" || ok=1
  assert_file_contains "$SKILL_MD" "**サイズを理由に、反映を保留しない・別テーマの節へ移さない**" || ok=1

  # Correcting a promoted claim: one search, the shortest needle, the origin, the heading.
  fix="$(bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-extract-section.sh" "$SKILL_MD" '昇格済み知見の誤認発覚時の修正フロー' 2>/dev/null)" || {
    echo "  FAIL: SKILL.md should have the correction flow"
    fix=""
    ok=1
  }
  assert_output_contains "$fix" 'framework/bin/kaizen-search-knowledge.sh' || ok=1
  assert_output_not_contains "$fix" 'grep -rn' || ok=1
  assert_output_contains "$fix" '最短の語に切る' || ok=1
  assert_output_contains "$fix" 'log -S' || ok=1
  assert_output_contains "$fix" '見出し・症状・対策の主張も、同じ回に見直す' || ok=1

  record_result "$test_name" "$ok"
  teardown_test_env
}

# --- Run ---

echo "=== reflect-learning structure tests ==="
test_layout
test_agents_read_criteria_only
test_reflector_payload
test_verifier_input
test_criteria_flow_split
test_section_references
test_migration_from_command
test_purpose_criteria
test_deliberate_lane
test_claims_and_size

print_results
