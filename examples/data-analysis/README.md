# Data Analysis Example

データ分析プロジェクト向けの Kaizen-CLI サンプル。

分析計画の構造化、データ前処理の落とし穴回避、コピペ用コードパターンを提供します。

## 含まれるファイル

```
examples/data-analysis/
├── knowledge/
│   └── analysis/
│       ├── INDEX.md            # 逆引きリファレンス
│       ├── PITFALLS.md         # 分析の落とし穴と対策
│       └── QUICK_REFERENCE.md  # 分析コードパターン集
└── .claude/
    └── skills/
        └── planning-analysis/
            └── SKILL.md        # 分析計画立案スキル
```

### knowledge/analysis/

| ファイル | 内容 |
|---------|------|
| INDEX.md | 「やりたいこと」から参照先を引くタスクディスパッチャー |
| PITFALLS.md | データ前処理・統計分析の落とし穴と対策 |
| QUICK_REFERENCE.md | データ前処理、統計チェック、分析パターンのコード集 |

### skills/planning-analysis/

分析プロジェクトの計画立案を構造化するスキル。仮説設計、反証仮説の設定、定量的な成功基準の定義を支援します。

## 使い方

これらのファイルはそのまま使うのではなく、自分のドメインに合わせてカスタマイズするための参考資料です。

1. knowledge/ のファイルを `$KAIZEN_KNOWLEDGE_DIR` にコピーして編集
2. skills/ のファイルをプロジェクトの `.claude/skills/` にコピーして編集
3. 自分の分析ドメインに合わせてコード例やチェックリストを追加・修正

カスタマイズの詳細は [docs/CUSTOMIZATION.ja.md](../../docs/CUSTOMIZATION.ja.md) を参照してください。
