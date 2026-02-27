# Kaizen-CLI

**Claude Code のための知識蓄積型ワークフローフレームワーク**

> 実務をこなしながら、知識は勝手に積み上がる。

[English README](README.md)

---

## Kaizen-CLI とは？

Claude Code で、プロジェクトが変わるたびに同じ説明を繰り返していませんか？プロジェクト固有のルールは CLAUDE.md で補えます。しかし、業界の専門知識、利用技術への深い知見、過去の失敗から学んだ予防線 — これらはプロジェクトを超えて蓄積されるべき知識であり、現状その仕組みがありません。

Kaizen-CLI は、改善のためのアクションを別に回すツールではありません。**実務の中に知識蓄積のループを埋め込む**フレームワークです。あなたは普段の作業 — 機能の実装、バグ修正、データ分析 — に集中するだけ。作業中に自然と生じる引っかかり — 想定外のエラー、調べ直した技法、うまくいったパターン — それがそのまま知識更新の材料になります。実務から生まれた知識が蓄積され、次の実務を加速させる。この繰り返しがKaizen-CLIのワークフローです。

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Init   │───▶│ Suggest │───▶│ Execute │───▶│ Reflect │
│         │    │  Next   │    │(= あなた│    │         │
│/kaizen  │    │/kaizen  │    │  の実務)│    │/kaizen  │
│-init    │    │-suggest │    │         │    │-reflect │
│-project │    │-next    │    │         │    │-learning│
└─────────┘    └─────────┘    └─────────┘    └─────────┘
                    ▲                              │
                    │  実務中の引っかかりが          │
                    │  knowledge/ を育て            │
                    │  次のサイクルを加速させる       │
                    └──────────────────────────────┘
```

## Kaizen-CLI が提供するもの

| 仕組み | 説明 |
|--------|------|
| **共有ナレッジベース** | `knowledge/` をsymlinkで全プロジェクトに共有（レジストリによる分離も可能）。業界知識・技術知見・失敗からの学びが蓄積される |
| **実務に埋め込まれたKaizenサイクル** | suggest → execute → reflect が実務を包み込む形で回る。改善のための別プロセスは不要 |
| **プロジェクトコンテキスト** | PROJECT_SUMMARY とレジストリでプロジェクト横断の文脈を保持 |

## なぜ Kaizen-CLI か？

- **余分なプロセスが要らない**: 改善案を別に考える必要はない。実務中に自然と生じる引っかかりがそのまま知識更新のインプットになる
- **知識が残る**: 学んだことが `knowledge/` ファイルに書き込まれ、すべてのプロジェクトで利用可能に
- **プロジェクト横断の学習**: シンボリックリンクによる知識共有で、1つのプロジェクトでの学びが全プロジェクトに波及
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
```

`setup.sh` は共有知識ディレクトリ（`$KAIZEN_KNOWLEDGE_DIR`）の作成と `kaizen-init-project` スキルのリンクを行います。各プロジェクトで `/kaizen-init-project` を実行すると、kaizen コマンドとシンボリックリンクがセットアップされます。`knowledge/` はこの共有ディレクトリ内のレジストリへのシンボリックリンクとなり、同じレジストリ内のプロジェクトで蓄積された知識が自動的に共有されます。レジストリを複数作成すれば（例: 職場用と個人用）、文脈ごとに知識を分離できます。

詳しいウォークスルーは [docs/QUICKSTART.ja.md](docs/QUICKSTART.ja.md) をご覧ください。

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
│   ├── bin/                 # ヘルパーシェルスクリプト
│   ├── templates/           # ロケール別テンプレート
│   │   ├── en/              # 英語テンプレート
│   │   └── ja/              # 日本語テンプレート
│   └── .claude/
│       ├── commands/        # ワークフロースラッシュコマンド
│       └── skills/          # 自動発動スキル定義
│
└── examples/                # ドメイン別サンプル
    ├── data-analysis/       # データ分析ワークフロー
    └── web-development/     # Web開発ワークフロー
```

## ドキュメント

- [CONCEPT.ja.md](docs/CONCEPT.ja.md) — Kaizen-CLI の思想
- [DESIGN_PRINCIPLES.ja.md](docs/DESIGN_PRINCIPLES.ja.md) — 設計原則とパターン
- [QUICKSTART.ja.md](docs/QUICKSTART.ja.md) — 5分で始める
- [CUSTOMIZATION.ja.md](docs/CUSTOMIZATION.ja.md) — 自分のドメインに適用する

## 対象ユーザー

**向いている人:**
- 小規模プロジェクトを多数こなす個人開発者・データアナリスト
- あるプロジェクトで得た知識を他のすべてのプロジェクトに引き継ぎたい Claude Code ユーザー
- 構造化されたAI支援開発ワークフローに興味がある人

**向いていない人:**
- 単一の長期プロジェクトで、プロジェクト横断の知識共有が不要な場合
- Claude Code を使っていないチーム

## コントリビューション

コントリビューション歓迎です！Issue または Pull Request をお気軽にどうぞ。

## ライセンス

[MIT](LICENSE)
