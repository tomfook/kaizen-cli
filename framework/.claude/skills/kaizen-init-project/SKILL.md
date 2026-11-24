---
name: kaizen-init-project
description: >-
  Initial setup for a Kaizen-CLI project.
  Creates knowledge/, skills/, commands/, and agents/ symlinks, generates CLAUDE.md and PROJECT_SUMMARY.md,
  and registers the project in the registry (details/ mirror + regenerated INDEX.md).
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
- `.claude/skills/`・`.claude/commands/`・`.claude/agents/` の `kaizen-*` — ここでは判定しない。Step 5 の `sync-links` が項目単位で判定する（既存の正しいリンクはそのまま、欠落は追加、宙吊りは除去、リンクでない実体は触れずに報告）
- `CLAUDE.md` — 既に存在する場合はユーザーに以下の3択を提示:
  1. **追記** — テンプレートの「Reference Documentation」「Kaizen-CLI Workflow」セクションを既存ファイルの末尾に追記
  2. **上書き** — テンプレートから新規生成（既存内容は失われる）
  3. **スキップ** — 何もしない
- `docs/PROJECT_SUMMARY.md` — 既に存在する場合はスキップ
- `docs/LEARNINGS.md` — 既に存在する場合はスキップ

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

入力されたレジストリ名のバリデーション（ヘルパースクリプトで検証）:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh" validate-registry-name "$REGISTRY_NAME"
```

- 終了コード `0` → 有効な名前（`^[a-z0-9][a-z0-9-]*$`）
- 終了コード `1` → 不正な名前。stderr のエラーメッセージをユーザーに表示し再入力を求める
- 終了コード `2` → 名前が未指定（使用法エラー）

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

**プロジェクトID ガード**: プロジェクトIDは、デフォルトでカレントディレクトリ名（`basename "$PWD"`）を採用し、ユーザーが変更したい場合は上書き可能。レジストリと ID が確定したら、採用する前に以下のガードを実施する（デフォルト値を採用する場合も必ず実施）。

1. **文字種・汎用語チェック**（ヘルパースクリプト）:

   ```bash
   bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh" validate-project-id "$PROJECT_ID"
   ```

   - 終了コード `0` → 有効。手順2の衝突チェックへ進む
   - 終了コード `1` → 不正な文字。stderr のエラーメッセージをユーザーに表示し、再入力を求めて手順1から再検証
   - 終了コード `2` → ID未指定（使用法エラー）
   - 終了コード `3` → 汎用的すぎる名前（`tmp`/`work`/`app` 等）。stderr の警告をユーザーに表示し、以下の2択を提示:
     1. **この ID で続行** — 警告を承知のうえ採用
     2. **別名を入力** — 新しい ID を入力させ、手順1から再検証

2. **レジストリ衝突チェック**:

   ```bash
   test -f "$KAIZEN_KNOWLEDGE_DIR/$REGISTRY_NAME/projects/details/$PROJECT_ID.md"
   ```

   - **ファイルが存在しない** → 衝突なし。チェック完了。
   - **ファイルが存在する** → まず初期化済みプロジェクトの再実行かどうかを判定:

     ```bash
     [ -L knowledge ] && [ "$(readlink knowledge)" = "$KAIZEN_KNOWLEDGE_DIR/$REGISTRY_NAME" ]
     ```

     - **上記が真、かつ `$PROJECT_ID` がデフォルト（`basename "$PWD"`）のまま** → 初期化済みプロジェクトの再実行であり、検出された `details/$PROJECT_ID.md` は自プロジェクト自身。「初期化済みプロジェクトの再実行を検出。`details/$PROJECT_ID.md` は Step 9 で再生成されます」と通知し、プロンプトなしで続行する。
     - **それ以外**（新規 init、または ID をデフォルトから変更している） → 別プロジェクトのデータを上書きする恐れがある。ユーザーに以下の2択を提示:
       1. **上書きして続行** — 既存の概要が Step 9 で上書きされることを承知のうえ採用
       2. **別の ID を入力** — 新しい ID を入力させ、手順1から再検証（ループ）

両ガードを通過するまで繰り返す。

### 4. knowledge/ symlinkの作成

```bash
# $REGISTRY_NAME は Step 3 で選択されたレジストリ名
ln -s "$KAIZEN_KNOWLEDGE_DIR/$REGISTRY_NAME" knowledge
```

### 5. skills / commands / agents の symlink 同期

配布物（スキル・コマンド・エージェント）へのリンクは、ヘルパースクリプトで同期する。リンクの作成ロジックはこのスクリプトだけが持つ（手で `ln -s` しない）:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh" sync-links
```

- 個別の項目ごとに symlink を作る（ユーザー独自のスキル・コマンド・エージェントと共存するため）。`kaizen-` 接頭辞の無い項目には触れない
- べき等: 配布側に増えた項目だけを張り、配布側から消えた項目の宙吊りリンクを外す。初期化済みプロジェクトでの再実行は、フレームワーク更新後の再同期として働く
- `kaizen-init-project` はグローバルリンク済みのため、プロジェクトには張らない

出力の `[kaizen-links]` ブロックを解析:

| 終了コード | `status` | 対応 |
|---|---|---|
| `0` | `synced` | `linked:` / `removed:` の行を Step 10 の完了確認で報告する |
| `0` | `unchanged` | 変更なし。そのまま続行 |
| `1` | `error` | `failed:` の行と `error` をユーザーに表示して終了（権限・ファイルシステムの問題） |
| `3` | `error` | `error` の内容をユーザーに表示して終了（配布側を読めていない） |

`foreign:` の行がある場合（配布名と同じ場所に、配布物へのリンクでない実体や別の場所へのリンクがある）: スクリプトは触れない。該当項目をユーザーに示し、意図した複製かどうかを確認する。意図しないものなら、ユーザーが削除したあとで `sync-links` を再実行すると配布版に戻る。

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

### 8. docs/LEARNINGS.md の生成

`$KAIZEN_CLI_DIR/framework/templates/$LANG/docs/LEARNINGS.md.template` を読み取り、プレースホルダを置換。

**置換対象**:
- `{{PROJECT_NAME}}`: Step 3で取得したプロジェクト名

> **NEXT_STEPS.md は scaffold しない**: `docs/NEXT_STEPS.md` は任意・必要時作成のため init では生成しない（空ファイルの量産を避ける）。`$LANG/docs/NEXT_STEPS.md.template` は `/kaizen-update-docs` や手動での新規作成時に参照するスケルトン。詳細は `knowledge/meta/DOCUMENTATION_GUIDELINES.md` § Document Role Boundaries。

### 9. プロジェクトレジストリへの登録

レジストリ（`knowledge/projects/`）への登録は、ヘルパースクリプトで行う。`INDEX.md` の行もミラーも手で書かない（どちらも `docs/PROJECT_SUMMARY.md` から作られる派生物で、手で書いた内容は次の同期で上書きされる）。

1. ミラーの作成（`details/{id}.md`。`details/`・`learnings/` ディレクトリもここで作られる）:

   ```bash
   bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-registry.sh" register knowledge --expect-id "$PROJECT_ID"
   ```

   プロジェクト ID は `docs/PROJECT_SUMMARY.md` の frontmatter（`project.id`）から読まれる。`--expect-id` は、それが Step 3 の ID と一致することの確認。`[kaizen-registry-register]` ブロックを解析:

   | `status` | 対応 |
   |---|---|
   | `ok` | `details=`（`created` / `updated` / `unchanged`）を Step 10 で報告する。`learnings=not-synced` は登録時点では正常（`docs/LEARNINGS.md` にエントリができたあとの `/kaizen-update-docs` で同期される） |
   | `skipped` | frontmatter に `registry: false` がある。登録しない（手順 2・3 もスキップ） |
   | `error`: `id mismatch` | Step 7 をスキップした既存の `docs/PROJECT_SUMMARY.md` の `project.id` が、Step 3 の ID と違う。どちらを採るかユーザーに確認し、frontmatter を直すか Step 3 の ID を改めて、再実行する（何も書き込まれていない） |
   | `error`: frontmatter が無い | 既存の `docs/PROJECT_SUMMARY.md` に `project:` の frontmatter が無い。テンプレート（`$KAIZEN_CLI_DIR/framework/templates/$LANG/docs/PROJECT_SUMMARY.md.template`）の frontmatter を先頭に足す案をユーザーに示し、承認後に再実行する |
   | `error`: その他 | `error=` の内容をユーザーに表示する |

2. INDEX の再生成:

   ```bash
   bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-registry.sh" sync-index knowledge
   ```

   `details/*.md` の frontmatter から `projects/INDEX.md` の一覧表を作り直す（`INDEX.md` が無ければテンプレートから作る）。べき等: 新規登録なら `added=1`、初期化済みプロジェクトの再実行なら `index=unchanged` か `updated=1` になる。`warning:`・`kept:` の行があれば、そのままユーザーに伝える。

3. knowledge/ のコミット（今回作ったファイルだけ）:

   ```bash
   bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-knowledge-commit.sh" \
     -m "kaizen init: register $PROJECT_ID" \
     -- knowledge/projects/INDEX.md "knowledge/projects/details/$PROJECT_ID.md"
   ```

   - Step 3 で新しいレジストリを作った場合は、展開したファイル（`knowledge/.lang`・`knowledge/meta/INDEX.md`・`knowledge/meta/GETTING_STARTED.md`・`knowledge/meta/DOCUMENTATION_GUIDELINES.md`）も同じコマンドのパスに足す
   - `git add -A` やパスを付けない `git commit` は使わない（knowledge/ は全プロジェクト・全セッションの共有物で、他セッションが編集途中のファイルまで自分のコミットに入る）
   - `status=committed` / `nothing` / `skipped`（git リポジトリでない）はそのまま続行。`status=error` は内容を警告として表示して続行する（詳細: `.claude/skills/kaizen-editing-knowledge/FILE_OPERATIONS.md § knowledge/ のコミット`）

### 10. 完了確認

```bash
# プロジェクト構造を表示
ls -la knowledge
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh" check-links
ls docs/PROJECT_SUMMARY.md
ls docs/LEARNINGS.md
```

`check-links` が `status=clean`（終了コード `0`）であることを確認する。`foreign:` の行は Step 5 で確認済みの項目で、差分には数えられない。

ユーザーに以下を案内:
- `knowledge/` が `$KAIZEN_KNOWLEDGE_DIR/$REGISTRY_NAME` へのsymlinkであること
- `.claude/skills/`・`.claude/commands/`・`.claude/agents/` に Kaizen-CLI の配布物への symlink が同期されたこと（Step 5 の `linked:` / `removed:` の項目。`unchanged` なら「変更なし」）
- 追加されたコマンド・スキル・エージェントは、**新しいセッションから**一覧に反映されること
- `CLAUDE.md` が生成されたこと
- `docs/PROJECT_SUMMARY.md` が生成されたこと
- `docs/LEARNINGS.md` が生成されたこと
- プロジェクトレジストリに登録されたこと（Step 9 の `details=` と `added=` / `index=` の値）
- `knowledge/projects/details/{id}.md` にプロジェクト概要のコピーが配置されたこと。正本は `docs/PROJECT_SUMMARY.md` で、レジストリ側は `/kaizen-update-docs` が同期する（手で編集しない）
- Step 9 のコミット結果（`status=committed` ならコミット済み。git リポジトリでなければその旨）

### 11. 次のステップの案内

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
| `knowledge/projects/` 配下の手編集 | `INDEX.md`・`details/`・`learnings/` は派生物。`kaizen-registry.sh` だけが書く |
