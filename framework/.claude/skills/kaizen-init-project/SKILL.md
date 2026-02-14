---
name: kaizen-init-project
description: >-
  Kaizen-CLIプロジェクトの初期セットアップ。手動実行専用。
  knowledge/のsymlink作成、skills/のsymlink作成、CLAUDE.md・PROJECT_SUMMARY.mdの生成、
  プロジェクトレジストリへの登録を行う。
  使い方: 「プロジェクトを初期化して」「/kaizen-init-project」
---

# kaizen-init-project

プロジェクト初期化スキル。

## 前提条件

- [ ] `$KAIZEN_CLI_DIR` が設定されている
- [ ] `$KAIZEN_KNOWLEDGE_DIR` が設定されている
- [ ] 上記が未設定の場合、`bash $KAIZEN_CLI_DIR/setup.sh` の実行を案内して終了

## 実行フロー

### 1. 環境検証

以下を確認し、問題があればエラーメッセージを表示して終了:

```bash
# 環境変数の存在チェック
echo "$KAIZEN_CLI_DIR"
echo "$KAIZEN_KNOWLEDGE_DIR"

# ディレクトリの存在チェック
ls "$KAIZEN_CLI_DIR/framework/.claude/skills/"
ls "$KAIZEN_KNOWLEDGE_DIR"
```

### 2. 既存ファイルの確認

上書き防止のため、以下が既に存在しないか確認:

- `knowledge/` — 既にsymlinkまたはディレクトリが存在する場合はスキップ
- `.claude/skills/` — 既にsymlinkが存在する場合はスキップ
- `CLAUDE.md` — 既に存在する場合はスキップ（ユーザーに確認）
- `docs/PROJECT_SUMMARY.md` — 既に存在する場合はスキップ

### 3. ユーザーへの質問

以下の情報をユーザーに質問して取得:

| 項目 | 用途 | 必須 |
|------|------|------|
| プロジェクト名 | PROJECT_SUMMARY.md, CLAUDE.md | 必須 |
| プロジェクトID | レジストリ登録用（英数字・ハイフン） | 必須 |
| プロジェクトの目的 | PROJECT_SUMMARY.md | 必須 |
| 概要（1行） | CLAUDE.md, レジストリ | 必須 |

### 4. knowledge/ symlinkの作成

```bash
ln -s "$KAIZEN_KNOWLEDGE_DIR" knowledge
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

`$KAIZEN_CLI_DIR/framework/CLAUDE.md.template` を読み取り、プレースホルダを置換してCLAUDE.mdを生成。

**置換対象**:
- `{{PROJECT_DESCRIPTION}}`: Step 3で取得した概要

### 7. docs/PROJECT_SUMMARY.md の生成

`$KAIZEN_CLI_DIR/framework/docs/PROJECT_SUMMARY.md.template` を読み取り、プレースホルダを置換。

```bash
mkdir -p docs
```

**置換対象**:
- `{{PROJECT_ID}}`: Step 3で取得したID
- `{{PROJECT_NAME}}`: Step 3で取得したプロジェクト名
- `{{PROJECT_PURPOSE}}`: Step 3で取得した目的
- `{{DATE}}`: 今日の日付

### 8. プロジェクトレジストリへの登録

`$KAIZEN_KNOWLEDGE_DIR/projects/INDEX.md` にプロジェクトを登録:

1. `$KAIZEN_KNOWLEDGE_DIR/projects/` ディレクトリが存在しない場合は作成
2. `INDEX.md` が存在しない場合は `$KAIZEN_CLI_DIR/framework/knowledge/projects/INDEX.md.template` から生成
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
- `knowledge/` が `$KAIZEN_KNOWLEDGE_DIR` へのsymlinkであること
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
| `$KAIZEN_KNOWLEDGE_DIR` の構造変更 | 他プロジェクトに影響（レジストリ登録を除く） |
