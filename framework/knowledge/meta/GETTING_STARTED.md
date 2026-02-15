# Kaizen-CLI 運用ガイド

プロジェクト横断のknowledgeファイルの管理と運用方法。

**重要**: プロジェクト横断ファイルのみ。プロジェクト固有の内容を追加しないこと。

---

## ファイル管理の基本

### プロジェクト構造（シンボリックリンクモデル）

```
project-root/
├── CLAUDE.md          # プロジェクト固有の設定
├── knowledge/         → $KAIZEN_KNOWLEDGE_DIR へのsymlink
├── .claude/
│   ├── commands/      # Kaizen-CLIコマンド（グローバル）
│   └── skills/        # スキルsymlink + カスタムスキル
└── docs/              # プロジェクト固有ドキュメント（任意）
```

**シンボリックリンクの利点**:
- 全プロジェクトが同じknowledgeファイルを参照（編集が自動的に伝播）
- 変更履歴はgitで管理（$KAIZEN_KNOWLEDGE_DIRがgitリポジトリの場合）
- コピー・上書きの問題がない

**編集ルール**:
- 通常作業中: 読み取り専用（参照のみ）
- プロジェクト横断で有用な知識を発見した場合: 明示的な意図を持って編集
- プロジェクト固有情報は絶対に追加しない（まず一般化）

### ファイル配置

| 配置場所 | 内容 | 用途 |
|---------|------|------|
| **knowledge/** | プロジェクト横断の知識 | 全プロジェクトで共有（reflect-learningの蓄積先） |
| **CLAUDE.md** | プロジェクト固有の重要情報 | 用語、データソース、成果物 |
| **docs/PROJECT_SUMMARY.md** | プロジェクト概要 | 目的、技術スタック、設計判断（レジストリ同期対象） |
| **docs/** | プロジェクト固有の詳細情報 | 計画、仕様書、意思決定ログ |

---

## 新規プロジェクトセットアップ

### 前提条件

- [ ] Kaizen-CLIのセットアップが完了している（`bash setup.sh` — 初回のみ）
- [ ] `$KAIZEN_CLI_DIR` と `$KAIZEN_KNOWLEDGE_DIR` 環境変数が設定済み

### 手順

新しいプロジェクトディレクトリでClaude Codeを起動し、以下を実行:

```
/kaizen-init-project
```

これにより:
1. `knowledge/` symlink → `$KAIZEN_KNOWLEDGE_DIR` を作成
2. `.claude/skills/` symlinks → `$KAIZEN_CLI_DIR/framework/.claude/skills/` を作成
3. テンプレートから `CLAUDE.md` を生成
4. テンプレートから `docs/PROJECT_SUMMARY.md` を生成
5. プロジェクトレジストリ（`$KAIZEN_KNOWLEDGE_DIR/projects/INDEX.md`）に登録

### セットアップ後チェックリスト

- [ ] `knowledge/` が `$KAIZEN_KNOWLEDGE_DIR` へのsymlinkになっている
- [ ] `.claude/skills/` にKaizen-CLIスキルへのsymlinkが含まれている
- [ ] `CLAUDE.md` が作成・カスタマイズされている
- [ ] `docs/PROJECT_SUMMARY.md` が作成され、各セクションが埋められている
- [ ] knowledgeファイルにプロジェクト固有情報が追加されていない

---

## 利用可能なコマンド・スキル

### スキル（グローバル — 全プロジェクトで使用可能）

| スキル | 用途 | 使うタイミング |
|-------|------|--------------|
| `/kaizen-init-project` | プロジェクトをKaizen-CLIで初期化 | 新規プロジェクトセットアップ時 |

### コマンド（プロジェクト内で使用）

| コマンド | 用途 | 使うタイミング |
|---------|------|--------------|
| `/kaizen-suggest-next` | 次のステップを提案 | タスク完了時 |
| `/kaizen-reflect-learning` | 学びをknowledgeファイルに記録 | セッション終了時 |
| `/kaizen-update-docs` | プロジェクトドキュメントを更新 | docs/やCLAUDE.mdの変更後 |

---

## ナレッジ更新ワークフロー

### knowledgeファイルを更新するタイミング

プロジェクト作業中に、全プロジェクトに有益な知見を発見した場合:

```
プロジェクト作業中
    ↓
「この知見は全プロジェクトで役立つ」
    ↓
ユーザーに報告し、更新の指示を受ける
    ↓
knowledgeファイルを編集（一般化 — プロジェクト固有情報なし）
    ↓
変更が即座に全プロジェクトで利用可能に（symlink経由）
```

### 追加すべきもの / すべきでないもの

**knowledgeファイルに追加するもの**:
- プロジェクト横断で発見された共通パターン
- 再利用可能なコードスニペットとテンプレート
- 落とし穴とその解決策
- 経験で検証されたベストプラクティス

**knowledgeファイルに追加しないもの**:
- プロジェクト名や識別子
- 具体的な数値目標やメトリクス
- プロジェクト固有の用語
- 特定のファイルパスやリソース名
- 一時的な制約

**迷ったとき**の判断基準:
1. 他のプロジェクトでも役立つか？ → Yes = knowledge候補
2. 1年後も有効か？ → Yes = knowledge候補
3. プロジェクト名を除去して一般化できるか？ → Yes = knowledge候補

3つとも「Yes」 → knowledgeファイルに追加。

> knowledgeファイルの編集ガイドライン詳細: [DOCUMENTATION_GUIDELINES.md](./DOCUMENTATION_GUIDELINES.md)

---
