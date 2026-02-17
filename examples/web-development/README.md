# Web Development Example

Web開発プロジェクト向けの Kaizen-CLI サンプル。

コードレビューの構造化、Web開発の落とし穴回避、コピペ用パターン集を提供します。

## 含まれるファイル

```
examples/web-development/
├── knowledge/
│   └── development/
│       ├── INDEX.md            # Reverse Lookup Reference
│       └── PATTERNS.md         # Web開発パターン集
└── .claude/
    └── skills/
        └── reviewing-code/
            └── SKILL.md        # コードレビュースキル
```

### knowledge/development/

| ファイル | 内容 |
|---------|------|
| INDEX.md | 「やりたいこと」から参照先を引くタスクディスパッチャー |
| PATTERNS.md | Web開発でよくある落とし穴と推奨パターン |

### skills/reviewing-code/

コードレビューを構造化するスキル。セキュリティ、パフォーマンス、保守性の観点からチェックリストベースのレビューを支援します。

## 使い方

これらのファイルはそのまま使うのではなく、自分のドメインに合わせてカスタマイズするための参考資料です。

1. knowledge/ のファイルを `$KAIZEN_KNOWLEDGE_DIR` にコピーして編集
2. skills/ のファイルをプロジェクトの `.claude/skills/` にコピーして編集
3. 自分の技術スタックに合わせてパターンやチェックリストを追加・修正

カスタマイズの詳細は [docs/CUSTOMIZATION.ja.md](../../docs/CUSTOMIZATION.ja.md) を参照してください。
