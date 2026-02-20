---
name: kaizen-init-project
description: >-
  Initial setup for a Kaizen-CLI project.
  Creates knowledge/ and skills/ symlinks, generates CLAUDE.md and PROJECT_SUMMARY.md,
  and registers the project in the registry.
  Usage: "/kaizen-init-project"
disable-model-invocation: true
---

# kaizen-init-project

プロジェクト初期化スキル。

## 前提条件

- [ ] `$KAIZEN_CLI_DIR` が設定されている
- [ ] `$KAIZEN_KNOWLEDGE_DIR` が設定されている
- [ ] 上記が未設定の場合、`bash $KAIZEN_CLI_DIR/setup.sh` の実行を案内して終了

## 実行フロー

### 1. 環境検証

ヘルパースクリプトを実行して環境を検証する:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh" verify
```

出力の `[kaizen-verify]` ブロックを解析:
- `status=error` → `error` の内容をユーザーに表示して終了
- `status=ok` → 以下の値を後続ステップで使用:
  - `registries` — Step 3 のレジストリ選択肢として表示
  - `kaizen_cli_dir` — テンプレートパスの基点
  - `template_dir` — テンプレートの存在確認

### 2. 既存ファイルの確認

上書き防止のため、以下が既に存在しないか確認:

- `knowledge/` — 既にsymlinkまたはディレクトリが存在する場合はスキップ
- `.claude/skills/` — 既にsymlinkが存在する場合はスキップ
- `CLAUDE.md` — 既に存在する場合はユーザーに以下の3択を提示:
  1. **追記** — テンプレートの「Reference Documentation」「Kaizen-CLI Workflow」セクションを既存ファイルの末尾に追記
  2. **上書き** — テンプレートから新規生成（既存内容は失われる）
  3. **スキップ** — 何もしない
- `docs/PROJECT_SUMMARY.md` — 既に存在する場合はスキップ

### 3. ユーザーへの質問

以下の情報をユーザーに質問して取得:

| 項目 | 用途 | 必須 | デフォルト |
|------|------|------|----------|
| レジストリ | knowledge/ symlink 先の選択 | 必須 | `default`（Enterでそのまま採用） |
| 言語 | テンプレートの言語選択（新規レジストリ作成時のみ質問） | 条件付き | `en` |
| プロジェクト名 | PROJECT_SUMMARY.md, CLAUDE.md | 必須 | — |
| プロジェクトID | レジストリ登録用（英数字・ハイフン） | 必須 | カレントディレクトリ名（`basename "$PWD"`） |
| プロジェクトの目的 | PROJECT_SUMMARY.md | 必須 | — |
| 概要（1行） | CLAUDE.md, レジストリ | 必須 | — |

**レジストリ選択**: `$KAIZEN_KNOWLEDGE_DIR` 直下のサブディレクトリを一覧し、常にユーザーに選択を求める（レジストリが1つでもスキップしない）。デフォルトは `default`（Enterでそのまま採用可能）。

入力されたレジストリ名のバリデーション: `^[a-z0-9][a-z0-9-]*$`（小文字英数字・ハイフンのみ）。不正な場合はエラーを表示し再入力を求める。

**言語検出**: 既存レジストリ選択時は `$REGISTRY_DIR/.lang` から言語を読み取る（ファイルが存在しない場合は `en` をデフォルト使用）。新規レジストリ作成時のみ言語を質問する（`en`/`ja`、デフォルト: `en`）。言語は `$LANG` 変数に格納し、テンプレートパスの決定に使用する。

存在しないレジストリ名が入力された場合:

1. 新しいレジストリとして作成するかユーザーに確認する
2. 承認された場合、言語を質問し（`en`/`ja`、デフォルト: `en`）、ディレクトリを作成しテンプレートを展開する:
   ```bash
   REGISTRY_DIR="$KAIZEN_KNOWLEDGE_DIR/$REGISTRY_NAME"
   TEMPLATE_DIR="$KAIZEN_CLI_DIR/framework/templates/$LANG"
   mkdir -p "$REGISTRY_DIR/meta" "$REGISTRY_DIR/projects"
   echo "$LANG" > "$REGISTRY_DIR/.lang"
   # 以下のテンプレートをコピー（存在しない場合のみ）
   # $TEMPLATE_DIR/knowledge/meta/INDEX.md.template → $REGISTRY_DIR/meta/INDEX.md
   # $TEMPLATE_DIR/knowledge/meta/GETTING_STARTED.md → $REGISTRY_DIR/meta/GETTING_STARTED.md
   # $TEMPLATE_DIR/knowledge/meta/DOCUMENTATION_GUIDELINES.md → $REGISTRY_DIR/meta/DOCUMENTATION_GUIDELINES.md
   # $TEMPLATE_DIR/knowledge/projects/INDEX.md.template → $REGISTRY_DIR/projects/INDEX.md
   ```
3. 拒否された場合、レジストリ選択に戻る

**プロジェクトID**: デフォルトでカレントディレクトリ名を使用する。ユーザーが変更したい場合は上書き可能。ディレクトリ名に英数字・ハイフン以外の文字が含まれる場合は、ユーザーに手動入力を求める。

### 4. knowledge/ symlinkの作成

```bash
# $REGISTRY_NAME は Step 3 で選択されたレジストリ名
ln -s "$KAIZEN_KNOWLEDGE_DIR/$REGISTRY_NAME" knowledge
```

### 5. skills/ symlinkの作成

個別スキルごとにsymlinkを作成（ユーザー独自スキルとの共存のため）:

```bash
mkdir -p .claude/skills

# kaizen-init-project はグローバルリンク済みのためスキップ
for skill_dir in "$KAIZEN_CLI_DIR/framework/.claude/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  if [ "$skill_name" = "kaizen-init-project" ]; then
    continue
  fi
  ln -s "$skill_dir" ".claude/skills/$skill_name"
done
```

### 6. CLAUDE.md の生成

`$KAIZEN_CLI_DIR/framework/templates/$LANG/CLAUDE.md.template` を読み取り、プレースホルダを置換してCLAUDE.mdを生成。

**置換対象**:
- `{{PROJECT_DESCRIPTION}}`: Step 3で取得した概要

**追記モード**（Step 2 で「追記」が選択された場合）:

1. 既存の CLAUDE.md を読み取る
2. テンプレートから以下のセクションを抽出:
   - `## Reference Documentation`（配下の小見出し含む）
   - `### Kaizen-CLI Workflow`
3. 既存 CLAUDE.md に各セクションの見出しが既に含まれているか確認
4. 含まれていないセクションのみ、既存ファイルの末尾に追記
5. プレースホルダ（`{{PROJECT_DESCRIPTION}}` 等）は追記内容にも適用する

### 7. docs/PROJECT_SUMMARY.md の生成

`$KAIZEN_CLI_DIR/framework/templates/$LANG/docs/PROJECT_SUMMARY.md.template` を読み取り、プレースホルダを置換。

```bash
mkdir -p docs
```

**置換対象**:
- `{{PROJECT_ID}}`: Step 3で取得したID
- `{{PROJECT_NAME}}`: Step 3で取得したプロジェクト名
- `{{PROJECT_PURPOSE}}`: Step 3で取得した目的
- `{{DATE}}`: 今日の日付

### 8. プロジェクトレジストリへの登録

選択されたレジストリ内の `projects/INDEX.md` にプロジェクトを登録（symlink経由で `knowledge/projects/INDEX.md` としてアクセス可能）:

1. `knowledge/projects/` ディレクトリが存在しない場合は作成
2. `knowledge/projects/INDEX.md` が存在しない場合は `$KAIZEN_CLI_DIR/framework/templates/$LANG/knowledge/projects/INDEX.md.template` から生成
3. INDEX.mdの一覧テーブルに行を追加:
   - `| {id} | {name} | planning | | {date} |`

### 9. 完了確認

```bash
# プロジェクト構造を表示
ls -la knowledge
ls -la .claude/skills/
ls docs/PROJECT_SUMMARY.md
```

ユーザーに以下を案内:
- `knowledge/` が `$KAIZEN_KNOWLEDGE_DIR/$REGISTRY_NAME` へのsymlinkであること
- `.claude/skills/` にKaizen-CLIスキルへのsymlinkが作成されたこと
- `CLAUDE.md` が生成されたこと
- `docs/PROJECT_SUMMARY.md` が生成されたこと
- プロジェクトレジストリに登録されたこと

### 10. 次のステップの案内

1. `docs/PROJECT_SUMMARY.md` の各セクションを埋める
2. `CLAUDE.md` をカスタマイズ
3. `knowledge/` の関連ファイルを確認
4. `/kaizen-suggest-next` で次のアクションを取得

---

## 禁止事項

| 禁止 | 理由 |
|------|------|
| 既存ファイルの上書き | ユーザーの作業内容を破壊する |
| テンプレートファイルの直接編集 | 全ユーザーに影響 |
| `$KAIZEN_CLI_DIR` 配下のファイル変更 | 配布元リポジトリを汚染 |
| `$KAIZEN_KNOWLEDGE_DIR` の構造変更 | 他プロジェクトに影響（レジストリ登録・新規レジストリ作成を除く） |
