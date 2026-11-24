# Unregister project from registry

プロジェクトをレジストリ（knowledge/projects/）から登録解除する。

**実行内容**:
1. details/<project-id>.md を削除
2. learnings/<project-id>.md を削除（存在する場合）
3. INDEX.md を残りの details/ から再生成（該当行が消える）
4. 削除した 2 ファイルと INDEX.md だけをコミット
5. ユーザーに手動クリーンアップを案内

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

- INDEX.md の行: <index_rowの内容（空なら「行なし（ミラーだけが残っている）」）>
- 詳細ファイル: knowledge/projects/details/<project-id>.md (<details_fileの状態>)
- 教訓ファイル: knowledge/projects/learnings/<project-id>.md (<learnings_fileの状態>)

レジストリから登録解除します。よろしいですか？
```

**重要**: ユーザーの明示的な承認なしに削除を実行しないこと。

### Step 6: 削除の実行

承認後、ヘルパースクリプトで削除:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-unregister.sh" execute "$(readlink -f knowledge)" "<project-id>"
```

`[kaizen-unregister-execute]` ブロックを解析し、結果をユーザーに報告。

- `INDEX.md` はスクリプトが再生成する（`kaizen-registry.sh sync-index`）。**手で行を消さない** — 表は `details/*.md` から作られる派生物で、手編集は次の同期で上書きされる
- `status=error` で `nothing was removed` とある場合、表を再生成できない状態（見出し行が無い等）のため、何も削除していない。`error=` の内容をユーザーに示す
- `warning:` の行（同じ id を持つ別名の details が残っている等）があれば、そのまま伝える

### Step 7: knowledge/ の自動コミット

Step 6 で削除したミラーと、再生成された INDEX だけをコミットする:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-knowledge-commit.sh" \
  -m "kaizen unregister: remove <project-id> from registry" \
  -- knowledge/projects/INDEX.md \
     knowledge/projects/details/<project-id>.md \
     knowledge/projects/learnings/<project-id>.md
```

- 削除済みのファイルもパスを渡す（削除がコミットされる）。もともと無かったパスは `skipped:` に出るだけで、残りはコミットされる
- `git add -A` やパスを付けない `git commit` は使わない — 他セッションが編集途中のファイルまで自分のコミットに入る

出力の `[kaizen-knowledge-commit]` ブロックの `status` で分岐:

| 終了コード | `status` | 対応 |
|---|---|---|
| `0` | `committed` | `message:` の件名と `committed:` のファイルが意図どおりか確認して報告 |
| `0` | `nothing` / `skipped` | 変更なし、または git リポジトリでない。そのまま続行 |
| `2` | `error` | git の失敗。`git:` / `failed:` の内容を警告として表示して続行 |
| `3` | `error` | パス・引数の誤り。`error=` を読んで直し、再実行する |

`other:` の行（今回のコミットに含めなかった他の未コミット変更）があれば、**触らず**、あることをユーザーに伝える。

> 詳細: `.claude/skills/kaizen-editing-knowledge/FILE_OPERATIONS.md § knowledge/ のコミット`

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
