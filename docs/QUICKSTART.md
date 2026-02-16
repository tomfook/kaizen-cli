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
3. テンプレートファイルを展開
4. コマンドとスキルをグローバルにリンク

```bash
# 環境変数を反映
source ~/.bashrc
```

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

- **プロジェクト名**: My Python Project
- **プロジェクトID**: `my-python-project`（ディレクトリ名から自動提案。Enterでそのまま採用）
- **プロジェクトの目的**: 日常業務を自動化するPythonスクリプト集
- **概要（1行）**: Pythonユーティリティスクリプトのコレクション

完了すると、以下が作成されます:

```
my-python-project/
├── CLAUDE.md              ← プロジェクト固有の設定
├── knowledge/             ← $KAIZEN_KNOWLEDGE_DIR へのsymlink
├── .claude/skills/        ← Kaizen-CLIスキルへのsymlink
└── docs/
    └── PROJECT_SUMMARY.md ← プロジェクト概要
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

### 3-2: Plan & Decide — 計画と判断

提案の中から「1. PROJECT_SUMMARY.md を埋める」を選びます。

```
1を実行しましょう
```

### 3-3: Execute — 実行（= あなたの実務）

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

### 3-4: Reflect — 引っかかりが知識に変わる

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

---

## これが Kaizen サイクルです

1. **Suggest**: 次にやることの提案を受ける
2. **Plan & Decide**: 何をやるか決める
3. **Execute**: 実務をこなす（= 普段の作業）
4. **Reflect**: 引っかかりを知識に変える

サイクルを回すたびに knowledge/ が育ち、同じ説明の繰り返し・手戻り・既知の落とし穴が減っていきます。

---

## Tips

- **knowledge/ のgit管理**: `$KAIZEN_KNOWLEDGE_DIR` で `git init` を実行すると、蓄積された知識の変更履歴を管理できます
- **セッションの終わりに**: `/kaizen-reflect-learning` を習慣にすると、知識が着実に蓄積されます
- **ドキュメントの更新**: 作業後に `/kaizen-update-docs` でプロジェクトドキュメントを最新化できます

---

## 関連ドキュメント

- Kaizen-CLI の思想を深く理解する → [CONCEPT.md](./CONCEPT.md)
- 設計原則を知る → [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md)
- 自分のドメインに合わせてカスタマイズする → [CUSTOMIZATION.md](./CUSTOMIZATION.md)
