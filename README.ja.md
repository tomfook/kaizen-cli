# Kaizen-CLI

**Claude Code のための知識蓄積型ワークフローフレームワーク**

> 使うほど速くなるAI開発ワークフロー

[English README](README.md)

---

## Kaizen-CLI とは？

Claude Code で、プロジェクトが変わるたびに同じ説明を繰り返していませんか？プロジェクト固有のルールは CLAUDE.md で補えます。しかし、業界の専門知識、利用技術への深い知見、過去の失敗から学んだ予防線 — これらはプロジェクトを超えて蓄積されるべき知識であり、現状その仕組みがありません。

Kaizen-CLI は、**セッションやプロジェクトを横断して知識を蓄積し、その知識を活かして次のアクションを提案する構造化ワークフロー**を提供します。使えば使うほど、AI の作業が速くなります。

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

## Kaizen-CLI が提供するもの

| 仕組み | 説明 |
|--------|------|
| **共有ナレッジベース** | `knowledge/` をsymlinkで全プロジェクトに共有。業界知識・技術知見・失敗からの学びが蓄積される |
| **Kaizenサイクル** | suggest → plan → execute → reflect のサイクルで継続的に改善 |
| **プロジェクトコンテキスト** | PROJECT_SUMMARY とレジストリでプロジェクト横断の文脈を保持 |

## なぜ Kaizen-CLI か？

- **知識が残る**: 学んだことが `knowledge/` ファイルに書き込まれ、将来のすべてのセッションで利用可能に
- **プロジェクト横断の学習**: シンボリックリンクによる知識共有で、1つのプロジェクトでの学びが全プロジェクトに波及
- **構造化された改善**: suggest → plan → execute → reflect の明示的サイクルで継続的改善を推進
- **回を重ねるごとに高速化**: 蓄積された知識により、同じ説明の繰り返し・手戻り・既知の落とし穴が減る

## クイックスタート

```bash
# 1. クローンしてセットアップ（初回のみ）
git clone https://github.com/tomfook/kaizen-cli.git
bash kaizen-cli/setup.sh

# 2. プロジェクトを初期化
cd your-project
claude  # Claude Code を起動し:
        # /kaizen-init-project    — knowledge/ のsymlinkとプロジェクト設定をセットアップ

# 3. Kaizenサイクルを開始
        # /kaizen-suggest-next    — 次ステップの提案を取得
        # /kaizen-reflect-learning — 学んだことを記録
        # /kaizen-update-docs     — プロジェクトドキュメントを更新
```

`setup.sh` は共有知識ディレクトリ（`$KAIZEN_KNOWLEDGE_DIR`）の作成とグローバルコマンドのインストールを行います。各プロジェクトの `knowledge/` はこの共有ディレクトリへのシンボリックリンクとなり、あるプロジェクトで蓄積された知識が他のすべてのプロジェクトで自動的に利用可能になります。

詳しいウォークスルーは [docs/QUICKSTART.md](docs/QUICKSTART.md) をご覧ください。

## リポジトリ構成

```
kaizen-cli/
├── docs/                    # 方法論とガイド
│   ├── CONCEPT.md           # Kaizen-CLI の思想
│   ├── DESIGN_PRINCIPLES.md # 設計原則
│   ├── QUICKSTART.md        # 5分で始めるガイド
│   └── CUSTOMIZATION.md     # 自分のドメインへの適用方法
│
├── framework/               # コピーして使うテンプレート一式
│   ├── CLAUDE.md.template   # プロジェクト用 CLAUDE.md テンプレート
│   ├── knowledge/           # 知識ベーステンプレート
│   │   └── meta/
│   └── .claude/
│       ├── commands/        # ワークフロースラッシュコマンド
│       └── skills/          # 自動発動スキル定義
│
└── examples/                # ドメイン別サンプル
    ├── data-analysis/       # データ分析ワークフロー
    └── web-development/     # Web開発ワークフロー
```

## ドキュメント

- [CONCEPT.md](docs/CONCEPT.md) — Kaizen-CLI の思想
- [DESIGN_PRINCIPLES.md](docs/DESIGN_PRINCIPLES.md) — 設計原則とパターン
- [QUICKSTART.md](docs/QUICKSTART.md) — 5分で始める
- [CUSTOMIZATION.md](docs/CUSTOMIZATION.md) — 自分のドメインに適用する

## 対象ユーザー

**向いている人:**
- 小規模プロジェクトを多数こなす個人開発者・データアナリスト
- セッション間で知識を引き継ぎたい Claude Code ユーザー
- 構造化されたAI支援開発ワークフローに興味がある人

**向いていない人:**
- 単一の長期プロジェクトで、プロジェクト横断の知識共有が不要な場合
- Claude Code を使っていないチーム

## コントリビューション

コントリビューション歓迎です！[CONTRIBUTING.md](CONTRIBUTING.md) をご覧ください。

## ライセンス

[MIT](LICENSE)
