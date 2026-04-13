# Unregister project from registry

プロジェクトをレジストリ（knowledge/projects/）から登録解除する。

**実行内容**:
1. INDEX.md から該当行を削除
2. details/<project-id>.md を削除
3. ユーザーに手動クリーンアップを案内

**使い方**:
```
/kaizen-unregister-project <project-id>
```

**注意**: レジストリからの登録解除のみ。シンボリンクやプロジェクトファイルの削除は行わない。

**言語**: ユーザーの言語に合わせて応答すること

---

## 実行手順

### Step 1: knowledge/ の確認

`knowledge/` symlinkが存在するか確認する。

存在しない場合:
- 「knowledge/ symlinkが見つかりません。/kaizen-init-project でプロジェクトを初期化してください。」と表示して終了

### Step 2: 登録済みプロジェクトの一覧取得

ヘルパースクリプトで一覧を取得:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-unregister.sh" list "$(readlink -f knowledge)"
```

`[kaizen-unregister-list]` ブロックを解析:
- `status=error` → `error` の内容を表示して終了
- `status=ok` → `projects` の値を後続ステップで使用

### Step 3: プロジェクトIDの特定

引数として `$ARGUMENTS` で project-id が渡される。

- 引数がない場合 → Step 2 の一覧をユーザーに表示し、IDの入力を求める
- 引数がある場合 → そのIDを使用

### Step 4: 削除対象の確認

ヘルパースクリプトで削除対象を表示:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-unregister.sh" show "$(readlink -f knowledge)" "<project-id>"
```

`[kaizen-unregister-show]` ブロックを解析:
- `status=error` → `error` の内容を表示して終了
- `status=ok` → 削除対象情報を次のステップで表示

### Step 5: ユーザー確認（必須・スキップ不可）

以下をユーザーに表示し、確認を取得:

```markdown
## 削除対象

- INDEX.md の行: <index_rowの内容>
- 詳細ファイル: knowledge/projects/details/<project-id>.md (<details_fileの状態>)

レジストリから登録解除します。よろしいですか？
```

**重要**: ユーザーの明示的な承認なしに削除を実行しないこと。

### Step 6: 削除の実行

承認後、ヘルパースクリプトで削除:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-unregister.sh" execute "$(readlink -f knowledge)" "<project-id>"
```

`[kaizen-unregister-execute]` ブロックを解析し、結果をユーザーに報告。

### Step 7: knowledge/ の自動コミット

1. `$KAIZEN_KNOWLEDGE_DIR` が git リポジトリかどうか確認:
   ```bash
   git -C "$KAIZEN_KNOWLEDGE_DIR" rev-parse --is-inside-work-tree
   ```
2. git リポジトリかつ未コミットの変更がある場合、自動コミット:
   ```bash
   git -C "$KAIZEN_KNOWLEDGE_DIR" add -A
   git -C "$KAIZEN_KNOWLEDGE_DIR" commit -m "kaizen unregister: remove <project-id> from registry"
   ```
3. git リポジトリでない場合はスキップ
4. コミットに失敗した場合、警告を表示して続行

### Step 8: 手動クリーンアップの案内

以下をユーザーに案内:

- `knowledge/` シンボリンクの削除（不要な場合）
- `.claude/commands/kaizen-*.md` シンボリンクの削除（不要な場合）
- `.claude/skills/` 内の kaizen 関連シンボリンクの削除（不要な場合）
- `.claude/agents/kaizen-*.md` シンボリンクの削除（不要な場合）
- プロジェクトディレクトリの削除（必要な場合）

「これらは手動で行ってください。」と案内する。

---

## 禁止事項

| 禁止 | 理由 |
|------|------|
| ユーザー確認なしの削除実行 | 誤操作防止 |
| `$KAIZEN_CLI_DIR` 配下のファイル変更 | 配布元リポジトリを汚染 |
| シンボリンクやプロジェクトファイルの自動削除 | ユーザーの作業内容を破壊する |

---

## 関連コマンド

| コマンド | 目的 |
|---------|------|
| `/kaizen-suggest-next` | 次のステップの提案 |
| `/kaizen-update-docs` | プロジェクトドキュメントの更新 |
| `/kaizen-reflect-learning` | knowledge/ への知見反映 |
