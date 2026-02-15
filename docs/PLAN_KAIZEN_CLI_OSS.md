# Kaizen-CLI オープンソース化 計画書

**作成日**: 2026-02-11
**ステータス**: 計画段階

---

## 概要

Claude Codeを活用した知識蓄積型ワークフロー「Kaizen-CLI」をオープンソースとして公開するプロジェクト。

現在社内で運用中のワークフロー（knowledge/ + commands/ + skills/ による継続的改善サイクル）から、ドメイン固有情報を除去し、**方法論 + 汎用フレームワーク + サンプルドメイン**の3点セットとして公開する。

---

## 背景と動機

### 解決する課題

Claude Codeの利用者の多くは「単発のコード生成ツール」として使っている。セッション間で知識が断絶し、同じ調査・同じ失敗を繰り返す。特に小規模プロジェクトを多数並行する業務では、この問題が顕著になる。

### 提供する価値

| 観点 | 内容 |
|------|------|
| **知識の蓄積** | セッション終了時のreflect-learningで学びをknowledgeファイルに定着 |
| **加速する開発** | 蓄積された知識により、類似タスクの実行速度が回を重ねるごとに向上 |
| **横断的な学習** | シンボリックリンクにより、1つのプロジェクトでの学びが全プロジェクトに波及 |
| **構造化された改善** | suggest-next → plan → execute → reflect の明示的改善サイクル |

### なぜ今か

- Claude Codeのskills/commands機能が成熟し、ワークフロー構築の基盤が整った
- 類似のフレームワークがまだ存在しない（先行者優位）
- 社内での十分な運用実績（27+プロジェクト、数ヶ月の運用）

---

## ターゲットユーザー

### 一次ターゲット

**小規模プロジェクトを多数こなす個人開発者・データアナリスト**

- 1-2週間で完了するプロジェクトを常時複数抱えている
- プロジェクト間で類似の作業パターンが繰り返される
- Claude Codeを既に使っているが、セッション間の知識断絶に課題を感じている

### 二次ターゲット

- Claude Codeのskills/commands機能に興味はあるが、設計パターンがわからない人
- AI支援開発のワークフロー設計に関心があるチーム
- 継続的改善サイクルをAI開発に組み込みたい人

---

## 公開する資産の分類

### Layer 1: 方法論（そのまま公開）

- Kaizenサイクルの定義と解説
- 設計原則（SSOT、INDEX逆引き、800行ルール、自動発動パターン）
- ワークフロー図（init → plan → do → reflect → suggest-next）
- 知識の層構造（skills = 手続き知識（静的）、knowledge = 参照知識（蓄積される）、commands = 操作）
- 知識蓄積の対象はknowledge/のみ（skills/は静的で変更しない）

### Layer 2: フレームワーク（汎用化して公開）

| 現行資産 | 公開版 | 変更内容 |
|---------|--------|---------|
| `init-usj/` skill | `kaizen-init-project/` | USJ固有のAWSリソース名・命名規則を除去 |
| `editing-context/` skill | `kaizen-editing-knowledge/` に改名 | SSOT・行数管理。汎用的 |
| `/usj-suggest-next` | `/kaizen-suggest-next` | `usj-`→`kaizen-`に変更、社内参照を除去 |
| `/usj-reflect-learning` | `/kaizen-reflect-learning` | 同上 |
| `/usj-update-docs` | `/kaizen-update-docs` | 同上、ai-projects/連携を汎用化 |
| `context/meta/INDEX.md` | `knowledge/meta/INDEX.md` テンプレート化 | 構造と書式のみ残す |
| `context/meta/DOCUMENTATION_GUIDELINES.md` | `knowledge/meta/` に配置、軽微な編集 | USJ固有ルールの除去 |
| `CLAUDE.md` | テンプレート化 | 構造のみ残し、内容は空欄 |

### Layer 3: サンプルドメイン（新規作成）

- **data-analysis**: 分析プロジェクト向け（planning-analysis、knowledge/analysis/の簡略版）
- **web-development**: Web開発向け（一般的なパターン、新規作成）

---

## リポジトリ構成

```
kaizen-cli/
├── README.md                           # 英語メイン + 日本語リンク
├── README.ja.md                        # 日本語版
├── LICENSE                             # MIT License
├── CLAUDE.md                           # このリポジトリ自体のCLAUDE.md（dogfooding）
├── setup.sh                            # 初回セットアップ（環境変数・グローバルコマンド配置）
│
├── docs/
│   ├── CONCEPT.md                      # 方法論の詳細解説
│   ├── DESIGN_PRINCIPLES.md            # 設計原則集
│   ├── QUICKSTART.md                   # 5分で始めるガイド
│   ├── CUSTOMIZATION.md                # 自分のドメインへの適用方法
│   └── images/                         # ワークフロー図等
│       └── pdca-cycle.png
│
├── framework/                          # コピーして使うテンプレート一式
│   ├── CLAUDE.md.template              # プロジェクト用CLAUDE.mdテンプレート
│   ├── docs/
│   │   └── PROJECT_SUMMARY.md.template # プロジェクト概要テンプレート
│   ├── knowledge/
│   │   ├── meta/
│   │   │   ├── INDEX.md.template       # 逆引きINDEXテンプレート
│   │   │   ├── DOCUMENTATION_GUIDELINES.md  # 汎用版ドキュメントガイドライン
│   │   │   └── GETTING_STARTED.md           # 使い方ガイド
│   │   └── projects/
│   │       └── INDEX.md.template       # プロジェクトレジストリテンプレート
│   └── .claude/
│       ├── commands/
│       │   ├── kaizen-suggest-next.md  # 次ステップ提案
│       │   ├── kaizen-reflect-learning.md # 知見反映
│       │   └── kaizen-update-docs.md   # ドキュメント更新
│       └── skills/
│           ├── kaizen-init-project/    # プロジェクト初期化（setup.shで~/.claude/skills/にグローバルリンク）
│           │   └── SKILL.md
│           └── kaizen-editing-knowledge/  # ナレッジ編集ガードレール
│               ├── SKILL.md
│               └── FILE_OPERATIONS.md
│
└── examples/                           # ドメイン別サンプル
    ├── data-analysis/
    │   ├── README.md                   # このサンプルの説明
    │   ├── knowledge/
    │   │   └── analysis/
    │   │       ├── INDEX.md
    │   │       └── QUICK_REFERENCE.md  # 分析用コードパターン（簡略版）
    │   └── .claude/
    │       └── skills/
    │           └── planning-analysis/
    │               └── SKILL.md
    └── web-development/
        ├── README.md
        ├── knowledge/
        │   └── development/
        │       ├── INDEX.md
        │       └── PATTERNS.md         # Web開発パターン集
        └── .claude/
            └── skills/
                └── reviewing-code/
                    └── SKILL.md
```

---

## フェーズ計画

### Phase 0: 準備（このプロジェクト内）

**目的**: 公開用リポジトリを作成する前に、計画と方針を固める

- [x] 本計画書の策定（本ドキュメント）
- [x] ライセンス選定の最終決定 → **MIT License**
- [x] リポジトリ名・ブランディングの確定 → **kaizen-cli**
- [x] 既存資産の機密情報スキャン（公開不可な情報の洗い出し）→ `docs/PHASE0_CONFIDENTIALITY_SCAN.md`

### Phase 1: リポジトリ基盤

**目的**: GitHubリポジトリを作成し、基本構造を構築する

- [x] GitHubリポジトリ作成（public）→ https://github.com/tomfook/kaizen-cli
- [x] ディレクトリ構造の作成
- [x] README.md（英語）の初版作成
- [x] README.ja.md（日本語）の初版作成
- [x] LICENSE（MIT）の配置
- [x] CLAUDE.md（このリポジトリ自体の）作成

### Phase 2: フレームワーク抽出

**目的**: 現行資産から汎用フレームワークを抽出する。最も工数がかかるフェーズ。

- [ ] commands/ の汎用化（`kaizen-` prefix で統一）
  - [x] kaizen-suggest-next.md: `usj-`→`kaizen-`、社内AWS参照除去
  - [ ] kaizen-reflect-learning.md: 同上
  - [ ] kaizen-update-docs.md: ai-projects/連携の汎用化
- [x] skills/ の汎用化
  - [x] kaizen-init-project/: init-usjからUSJ固有テンプレート参照を除去。サブタイプなし（汎用1パターン）。setup.shで~/.claude/skills/にグローバルリンク。ユーザーによるカスタムサブタイプ追加は CUSTOMIZATION.md で案内。skills は個別スキルごとに symlink（ユーザー独自スキルとの共存のため）
  - [x] kaizen-editing-knowledge/: editing-contextから改名（SSOT・行数管理は汎用）
- [x] knowledge/meta/ テンプレート作成
  - [x] INDEX.md.template: 構造のみ残し、内容をプレースホルダに
  - [x] DOCUMENTATION_GUIDELINES.md: USJ固有ルール除去
  - [x] GETTING_STARTED.md: 汎用版に書き換え（テンプレート不要のため.mdに変更）
- [x] CLAUDE.md.template 作成
- [x] docs/PROJECT_SUMMARY.md.template 作成
- [x] knowledge/projects/INDEX.md.template 作成（プロジェクトレジストリ）
- [ ] setup.sh 作成（初回セットアップ）
  - $KAIZEN_CLI_DIR を自動検出して環境変数に設定
  - $KAIZEN_KNOWLEDGE_DIR ディレクトリ作成
  - knowledge/meta/ テンプレートを $KAIZEN_KNOWLEDGE_DIR に展開
  - knowledge/projects/ テンプレートを $KAIZEN_KNOWLEDGE_DIR に展開
  - 両環境変数を ~/.bashrc 等に追記
  - グローバルコマンドを ~/.claude/commands/ にコピー（既存コマンドの衝突チェック付き）
  - kaizen-init-project スキルを ~/.claude/skills/kaizen-init-project/ にグローバルリンク
  - $KAIZEN_KNOWLEDGE_DIR の git init はしない（ユーザー判断。QUICKSTART.md で案内）

### Phase 3: 方法論ドキュメント

**目的**: Kaizen-CLIの考え方を文書化する。OSSの価値の核心部分。

- [ ] docs/CONCEPT.md
  - Kaizenサイクルの定義
  - 各フェーズの詳細説明（init → plan → do → reflect → suggest-next）
  - 知識蓄積のメカニズム（なぜ使うほど速くなるか）
  - 対象ユーザー像と非対象ユーザー像
- [ ] docs/DESIGN_PRINCIPLES.md
  - SSOT（Single Source of Truth）
  - INDEX逆引きパターン（「やりたいことから探す」）
  - ファイルサイズ管理（800行ルール）
  - スキル自動発動パターン
  - シンボリックリンクによる横断共有
  - 知識の層構造（skills / knowledge / commands）
- [ ] docs/QUICKSTART.md
  - 5分で始められる最小手順
  - 最初のPDCAサイクルを回すまでのウォークスルー
- [ ] docs/CUSTOMIZATION.md
  - 自分のドメイン向けknowledgeの追加方法
  - 新しいskillの作り方
  - commandのカスタマイズ方法
- [ ] ワークフロー図の作成（Mermaid or PNG）

### Phase 4: サンプルドメイン

**目的**: 具体的な利用イメージを伝えるサンプルを用意する

- [ ] examples/data-analysis/
  - 分析プロジェクト向けのknowledge/とskills/のサンプル
  - planning-analysisスキルの簡略版
  - 機密情報を含まないサンプルデータパターン
- [ ] examples/web-development/
  - Web開発向けのknowledge/とskills/のサンプル
  - コードレビュースキルのサンプル
  - 新規作成（社内資産の流用なし）

### Phase 5: 公開・告知

**目的**: 公開し、初期ユーザーを獲得する

- [ ] GitHub Actionsの設定（リンク切れチェック等の軽量CI）
- [ ] CONTRIBUTING.md の作成
- [ ] Issue templatesの作成
- [ ] 最終レビュー（機密情報の残存チェック）
- [ ] v0.1.0 タグ作成・リリース
- [ ] 告知
  - [ ] Zenn記事（日本語、方法論の解説）
  - [ ] GitHub Discussions / Reddit / Hacker News 等（英語）

### Phase 6: プラグイン対応

**目的**: Claude Code プラグインとしても配布可能にする。Phase 5完了後に着手。

- [ ] プラグイン仕様の調査（`.claude-plugin/plugin.json` の構造、制約の把握）
- [ ] `.claude-plugin/plugin.json` マニフェスト作成
- [ ] skills/ と commands/ をプラグイン規約に沿って配置
- [ ] `/plugin install` での導入テスト
- [ ] プラグインマーケットプレイスへの登録申請

---

## ブランディング

| 項目 | 決定 |
|------|------|
| **プロジェクト名** | Kaizen-CLI |
| **リポジトリ名** | `kaizen-cli` |
| **サブタイトル** | A knowledge-accumulating workflow framework for Claude Code |
| **キャッチコピー（英語）** | Your AI gets smarter the more you use it |
| **キャッチコピー（日本語）** | 使うほど速くなるAI開発ワークフロー |
| **言語** | ドキュメント: 日英バイリンガル / コード・テンプレート: 英語 |

---

## リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| 社内機密情報の漏洩 | 高 | Phase 0で機密スキャン実施。Phase 2で逐一レビュー。最終チェックをPhase 5に設定 |
| Claude Code仕様変更 | 中 | skills/commands/knowledgeの基本構造は安定。変更時はIssueで追従 |
| ユーザーが集まらない | 低 | Zenn記事で方法論を先に広め、ツールは後追いで認知させる |
| 方法論の説明が伝わらない | 中 | QUICKSTARTで5分体験を用意。抽象論より具体例を重視 |
| メンテナンス負荷 | 中 | 最小構成で公開し、フィードバック駆動で拡張。社内版との同期は手動 |

---

## アーキテクチャ: 知識の分離

kaizen-cli リポジトリは**配布専用（read-only）**。ユーザーの蓄積知識は別の場所に持つ。

```
kaizen-cli/                  ← upstream。git pull で安全に更新可能
  framework/
    .claude/commands/        ← ~/.claude/commands/ にコピーして使う
    .claude/skills/          ← kaizen-init-projectがグローバルリンク、他skillsは各プロジェクトにリンク
    knowledge/meta/          ← テンプレートのみ（知識の蓄積先ではない）

$KAIZEN_KNOWLEDGE_DIR/       ← ユーザーが作成する共有知識リポジトリ
  meta/                      ← INDEX.md, DOCUMENTATION_GUIDELINES.md 等
  projects/                  ← プロジェクトレジストリ（INDEX.md + 一覧）
  （ドメイン別サブディレクトリ）← 蓄積される知識（reflect-learningの蓄積先）

your-project/
  knowledge/                 ← $KAIZEN_KNOWLEDGE_DIR へのsymlink
  .claude/skills/            ← kaizen-cli/framework の skills へのsymlink
  CLAUDE.md                  ← プロジェクト固有の設定
  docs/PROJECT_SUMMARY.md    ← プロジェクト概要（レジストリ同期対象）
```

**環境変数**:

| 変数 | 設定方法 | 用途 |
|------|---------|------|
| `KAIZEN_CLI_DIR` | setup.sh がクローン先パスを自動検出して設定 | kaizen-init-project が skills/ への symlink を張る |
| `KAIZEN_KNOWLEDGE_DIR` | setup.sh がディレクトリ作成時に設定 | kaizen-init-project が knowledge/ への symlink を張る |

---

## 制約・前提条件

- **Claude Code依存**: このフレームワークはClaude Codeのskills/commands機能を前提とする。他のAIツールへの移植は対象外
- **社内版との関係**: OSSはフォーク。社内版（00_dsci_common）とは独立に管理。双方向の反映は手動判断
- **言語**: テンプレート・コマンド・スキル内の記述は英語。ドキュメント（docs/）は日英バイリンガル。コマンド・スキルには「ユーザーの言語に合わせて応答すること」という指示を含める
- **個人プロジェクト**: 会社のOSSではなく個人GitHubアカウントで公開（社内固有情報を含まないため問題なし）

---

## 成功指標

### 短期（公開後1ヶ月）

- GitHub Stars: 50+
- Zenn記事のViews: 1,000+
- 実際にフレームワークを使い始めた報告: 3件+

### 中期（公開後3ヶ月）

- GitHub Stars: 200+
- 外部からのPR/Issue: 5件+
- サンプルドメインの追加（コミュニティ貢献）: 1件+

---

## 補足: Kaizenサイクル図

```
                    ┌──────────────────────────────────────────────┐
                    │                                              │
                    ▼                                              │
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Init   │───▶│ Suggest │───▶│ Plan &  │───▶│ Execute │───▶│ Reflect │
│         │    │         │    │ Decide  │    │         │    │         │
│/kaizen  │    │/kaizen  │    │         │    │skills   │    │/kaizen  │
│-init    │    │-suggest │    │plan     │    │auto-    │    │-reflect │
│-project │    │-next    │    │mode     │    │invoke   │    │-learning│
│         │    │         │    │         │    │         │    │         │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘
                    ▲                                              │
                    │          Knowledge accumulates               │
                    │       in knowledge/ over cycles              │
                    └──────────────────────────────────────────────┘
```

---

## 次のアクション

本計画書の承認後、Phase 0の機密スキャンから着手する。
