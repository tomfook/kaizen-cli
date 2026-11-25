# クイックスタート

5分でKaizen-CLIをセットアップし、最初のKaizenサイクルを体験するガイドです。

## 前提条件

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) がインストール済み
- git がインストール済み
- bash が利用可能（macOS / Linux）

---

## Step 1: Kaizen-CLI のセットアップ（初回のみ）

```bash
# クローン
git clone https://github.com/tomfook/kaizen-cli.git

# セットアップ実行
bash kaizen-cli/setup.sh
```

setup.sh が以下を行います:

1. `$KAIZEN_CLI_DIR` を自動検出して `~/.bashrc` に設定
2. 共有ナレッジディレクトリ（`$KAIZEN_KNOWLEDGE_DIR`）のパスを確認・作成
3. ナレッジレジストリを選択・作成（デフォルト: `default`）
4. テンプレート言語を選択（`en` または `ja`、デフォルト: `en`）— `$REGISTRY_DIR/.lang` に保存
5. テンプレートファイルを選択した言語で選択したレジストリ内に展開
6. `$KAIZEN_KNOWLEDGE_DIR` を git リポジトリとして初期化（初期化済みの場合はスキップ）
7. `kaizen-init-project` スキルをグローバルにリンク

```bash
# 環境変数を反映
source ~/.bashrc
```

---

## アップグレード（既存ユーザー向け）

kaizen-cli を新しいバージョンに更新した後は、`setup.sh --force` を実行して最新の変更を適用します。

```bash
cd kaizen-cli
git pull
bash setup.sh --force
source ~/.bashrc   # または: source ~/.zshrc
```

### `--force` が行うこと

| 操作 | 詳細 |
|---|---|
| 環境変数の更新 | シェルRCファイル内の `$KAIZEN_CLI_DIR` と `$KAIZEN_KNOWLEDGE_DIR` を再設定 |
| シンボリックリンクの再リンク | `kaizen-init-project` スキルのシンボリックリンクを最新版に再作成 |
| レガシーコマンドのクリーンアップ | プロジェクトローカルに移行済みの旧グローバルkaizenコマンドを削除 |
| ナレッジ構造の自動マイグレーション | 旧フラットレイアウトのknowledgeを検出し、レジストリベースのレイアウトに移行 |

### 保持されるもの

- **knowledgeファイルは上書きされません** — 蓄積されたユーザーデータはすべてそのまま残ります
- レジストリの選択と言語設定（`.lang`）は維持されます
- 既存のプロジェクト設定は影響を受けません

> **いつ `--force` を実行すべき？** `git pull` で kaizen-cli を更新するたびに実行してください。繰り返し実行しても安全です。

> **既存プロジェクトに新コマンドを反映するには？** コマンド・スキル・エージェントはプロジェクトごとに個別の symlink で届くため、`git pull` で増えた項目は既存プロジェクトには自動では届きません。プロジェクトのディレクトリでリンクを同期してください:
>
> ```bash
> bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh" sync-links
> ```
>
> べき等です。新しい項目のリンクを追加し、改名・削除された項目への宙吊りリンクを外します。ユーザー独自のスキル・コマンド・エージェント（`kaizen-` 接頭辞の無いもの）には触れません。コマンドの一覧はセッション開始時に読み込まれるので、同期後は Claude Code の新しいセッションを開始してください。`/kaizen-init-project` を再実行しても、フローの中で同じ同期が行われます。
>
> **プロジェクトのリンクが古いことに気づくには？** `/kaizen-suggest-next` と `/kaizen-audit-knowledge` が最初にリンクを確認し、欠落・宙吊りの項目と同期コマンドを表示します。手動で確認する場合は `kaizen-init.sh check-links` を実行してください（終了コード `0` = 同期済み、`1` = 差分あり）。

> **更新後に `/kaizen-reflect-learning` が見つからない。** 単一のコマンドファイルから、スキルディレクトリへ移りました。2 つのサブエージェントが、メインのフローを読まずに判定基準だけを読めるようにするためです。移行前にリンクしたプロジェクトには旧ファイルへのリンクが残っていて、その先はもうありません。各プロジェクトで上の `sync-links` を実行し、新しいセッションを開始してください。古いリンクを外し、新しいリンクを追加します。実行の仕方は変わりません（`/kaizen-reflect-learning`）。コマンドを自分のコピーに差し替えていた場合（`.claude/commands/kaizen-reflect-learning.md` がリンクでなくファイル）、`sync-links` はそのコピーを残しますが、実行されるのはコピーではなくなります。Claude Code は、同名のコマンドよりスキルを優先するためです。変更した内容はスキルディレクトリ（`.claude/skills/kaizen-reflect-learning/`）のコピーへ移し、古いファイルは削除してください。

> **新しい `knowledge/projects/learnings/` ディレクトリはどうなる？** アップグレード後、各登録プロジェクトで `/kaizen-update-docs` を初回実行した時に自動生成されます。手動操作は不要 — 既存の `docs/LEARNINGS.md` は次回以降の `/kaizen-audit-knowledge` クロスプロジェクトパスへの入力になります。

> **`knowledge/projects/INDEX.md` の一覧表はどうなる？** 行ごとに編集する方式をやめ、`knowledge/projects/details/*.md`（各プロジェクトの `docs/PROJECT_SUMMARY.md` のコピー）の frontmatter から生成する方式になりました。アップグレード後に最初に実行した `/kaizen-update-docs` が、表を作り直します。行は作成日の順に並びます。details ファイルの無いプロジェクトの行は、そのまま残してその旨を報告します。表の前後の文章には触れません。以後、行を変えたいときは、そのプロジェクトの `docs/PROJECT_SUMMARY.md` を編集し、そのプロジェクトで `/kaizen-update-docs` を実行してください。表を直接直しても上書きされます。

> **`knowledge/` を手で編集した分は、自動ではコミットされなくなりました。** 各コマンドは、自分が変更したファイルだけをコミットします。以前は knowledge のリポジトリにある未コミットの変更をすべてコミットしていたため、他のセッションが編集途中の変更まで入っていました。knowledge のファイルを手で編集したときは、自分でコミットしてください:
>
> ```bash
> bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-knowledge-commit.sh" -m "kaizen: <変更内容>" -- knowledge/<path/to/file.md>
> ```
>
> 指定したファイルだけをコミットします。追加した行が、存在しない見出しやファイルを指している場合は、コミットせずに止まります。

---

## Step 2: プロジェクトの初期化

既存のプロジェクトディレクトリで Claude Code を起動し、`/kaizen-init-project` を実行します。

```bash
cd ~/my-python-project
claude
```

Claude Code 内で:

```
/kaizen-init-project
```

いくつかの質問に答えます:

- **レジストリ**: `default`（Enterでそのまま採用。別のレジストリ名を入力して切り替え可能）
- **プロジェクト名**: My Python Project
- **プロジェクトID**: `my-python-project`（ディレクトリ名から自動提案。Enterでそのまま採用）
- **プロジェクトの目的**: 日常業務を自動化するPythonスクリプト集
- **概要（1行）**: Pythonユーティリティスクリプトのコレクション

完了すると、以下が作成されます:

```
my-python-project/
├── CLAUDE.md              ← プロジェクト固有の設定
├── knowledge/             ← $KAIZEN_KNOWLEDGE_DIR/default へのsymlink
├── .claude/skills/        ← Kaizen-CLIスキルへのsymlink
└── docs/
    ├── PROJECT_SUMMARY.md ← プロジェクト概要
    └── LEARNINGS.md       ← プロジェクト固有の教訓
```

`knowledge/` が共有ディレクトリへのsymlinkになっていることがポイントです。他のプロジェクトで蓄積された知識が、ここからすぐに参照できます。

---

## Step 3: 最初のKaizenサイクルを回す

ここからは架空のシナリオで、Kaizenサイクルの一連の流れを体験します。

### 3-1: Suggest — 次のアクションの提案

```
/kaizen-suggest-next
```

初期化直後なので、以下のような提案が出ます:

```markdown
## 次のステップ提案

**今回の作業**: プロジェクトの初期セットアップ

### 発展的なアクション

1. [ ] **docs/PROJECT_SUMMARY.md の各セクションを埋める**: 技術スタックや
   設計判断を記録しておくと、将来のセッションで文脈の再説明が不要になる
   → 理由: プロジェクトの目的と制約が明文化されていると作業効率が上がる

2. [ ] **CLAUDE.md をカスタマイズ**: プロジェクト固有のコーディング規約や
   重要なルールを追記する
   → 理由: Claude Code が最初に読むファイルなので、ここに書くと即座に反映される

どの提案を実行しますか？
```

### 3-2: Execute — 実行（= あなたの実務）

提案の中から「1. PROJECT_SUMMARY.md を埋める」を選びます。

Claude Code と一緒に PROJECT_SUMMARY.md を編集します。

```
技術スタックのセクションを埋めてください。
Python 3.11を使っています。依存管理はpipです。
```

Claude Code が編集を進めますが、あなたが修正を入れたとします:

```
待って、venvじゃなくてuvを使っています。修正して。
```

この「修正」が、Reflect で知識として捉えられるシグナルです。作業中に自然と生じる引っかかり — これが知識の材料になります。

### 3-3: Reflect — 引っかかりが知識に変わる

作業が終わったら、知見を反映します。

```
/kaizen-reflect-learning
```

Claude Code がセッションを分析し、以下のような提案を出します:

```markdown
## 知見の分析

### 抽出した知見

1. **暗黙のルールの明文化**: ユーザーはPythonの依存管理にuvを使用している。
   venvを前提とした提案は修正が必要だった。
   - 一般化: 「Pythonプロジェクトの依存管理ツールはプロジェクトごとに異なる。
     推測せず確認すること」
   - 反映先: knowledge/ に追加

### 一般化条件チェック
- [x] 単発の例外ではない（他のプロジェクトでも該当する）
- [x] 効率向上に寄与する（次回から推測せず確認できる）
- [x] セッション中に修正が発生した（無条件採用）

承認しますか？
```

承認すると、knowledge/ に知見が書き込まれます。この知見は **symlink を通じて、今後すべてのプロジェクトで即座に利用可能** になります。

次にPythonプロジェクトを初期化したとき、Claude Code は knowledge/ からこの知見を読み取り、依存管理ツールを推測せずに確認するようになります。

### 3-4: Update Docs — プロジェクトドキュメントとレジストリの同期

knowledge/ が更新されたら、プロジェクト側のドキュメントも最新化します。

```
/kaizen-update-docs
```

Claude Code が CLAUDE.md と docs/ を分析し、更新を提案します:

```markdown
## ドキュメント更新提案

### docs/ の更新

#### PROJECT_SUMMARY.md
- 技術スタック: 依存管理ツールに uv を追加
- status: planning → developing

承認しますか？
```

承認すると、PROJECT_SUMMARY.md が更新されます。変更はプロジェクトレジストリ（`knowledge/projects/INDEX.md`）にも自動同期されます。これにより、別プロジェクトで `/kaizen-suggest-next` を実行した際に、このプロジェクトの最新状況が参照可能になります。

---

## これが Kaizen サイクルです

1. **Suggest**: 次にやることの提案を受ける
2. **Execute**: 実務をこなす（= 普段の作業）
3. **Update Docs**: プロジェクトドキュメントとレジストリを同期する
4. **Reflect**: 引っかかりを知識に変える

サイクルを回すたびに knowledge/ が育ち、同じ説明の繰り返し・手戻り・既知の落とし穴が減っていきます。

---

## Tips

- **knowledge/ のgit管理**: `setup.sh` が `$KAIZEN_KNOWLEDGE_DIR` に git リポジトリを自動初期化します。リモートバックアップには `git -C $KAIZEN_KNOWLEDGE_DIR remote add origin <url> && git -C $KAIZEN_KNOWLEDGE_DIR push -u origin main` でリモートを追加してください
- **作業が一段落ついたら**: `/kaizen-update-docs` → `/kaizen-reflect-learning` を習慣にすると、ドキュメントが常に最新に保たれ、知識が着実に蓄積されます
- **プロジェクトのレジストリ登録解除**: `/kaizen-unregister-project <project-id>` でレジストリのエントリを削除できます。symlinkやプロジェクトファイルは削除されません — 必要に応じて手動で削除してください
- **knowledge/ の品質監査**: `/kaizen-audit-knowledge` を定期的に実行してください。2 パスで動作します — 1 つは `knowledge/` 内の冗長情報・SSOT違反・陳腐化を検出、もう 1 つは各プロジェクトの `docs/LEARNINGS.md` を横断スキャンして共有 `knowledge/` への昇格候補を提示。どちらもユーザー承認後に反映されます
- **昇格済みエントリのマーキング**: `docs/LEARNINGS.md` の教訓を `knowledge/` に昇格させた後は、元のエントリ末尾に `- **昇格先**: → knowledge/<path>.md § <セクション名>` bullet を追加してください。クロスプロジェクト監査がこのマーカーを読み取り、次回以降の候補から除外します（マーカーがないと同じ教訓が監査のたびに再浮上します）

---

## 関連ドキュメント

- Kaizen-CLI の思想を深く理解する → [CONCEPT.ja.md](./CONCEPT.ja.md)
- 設計原則を知る → [DESIGN_PRINCIPLES.ja.md](./DESIGN_PRINCIPLES.ja.md)
- 自分のドメインに合わせてカスタマイズする → [CUSTOMIZATION.ja.md](./CUSTOMIZATION.ja.md)
