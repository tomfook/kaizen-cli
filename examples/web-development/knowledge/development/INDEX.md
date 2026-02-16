# Web開発ガイド - 逆引きリファレンス

開発ナレッジの入口。「やりたいこと」から参照先を引くタスクディスパッチャー。

**⚠️ 重要**: プロジェクト横断の汎用ファイル（プロジェクト固有の内容は禁止）

---

## やりたいことから探す

### クイックスタート

| やりたいこと | 参照先 |
|------------|-------|
| **Web開発パターンを確認したい** | **[PATTERNS.md](./PATTERNS.md)** |
| **コードレビューをしたい** | [reviewing-code skill](../../.claude/skills/reviewing-code/SKILL.md) |

### セキュリティ

| やりたいこと | 参照先 |
|------------|-------|
| 入力バリデーションを設計したい | [PATTERNS.md § 1.1](./PATTERNS.md#11-入力バリデーション) |
| 認証・認可を設計したい | [PATTERNS.md § 1.2](./PATTERNS.md#12-認証認可) |
| CORS設定を確認したい | [PATTERNS.md § 1.3](./PATTERNS.md#13-cors設定) |

### パフォーマンス

| やりたいこと | 参照先 |
|------------|-------|
| N+1クエリを防ぎたい | [PATTERNS.md § 2.1](./PATTERNS.md#21-n1クエリ) |
| キャッシュ戦略を選びたい | [PATTERNS.md § 2.3](./PATTERNS.md#23-キャッシュ戦略) |

### エラーハンドリング

| やりたいこと | 参照先 |
|------------|-------|
| APIエラーレスポンスを設計したい | [PATTERNS.md § 3.1](./PATTERNS.md#31-api境界のエラー設計) |
| HTTPステータスコードを選びたい | [PATTERNS.md § 3.1](./PATTERNS.md#31-api境界のエラー設計) |
| 非同期処理のエラー対策を確認したい | [PATTERNS.md § 3.2](./PATTERNS.md#32-非同期処理のエラー) |

### テスト

| やりたいこと | 参照先 |
|------------|-------|
| テスト戦略を設計したい | [PATTERNS.md § 4.1](./PATTERNS.md#41-テストピラミッド) |
| テストの書き方の注意点を確認したい | [PATTERNS.md § 4.2](./PATTERNS.md#42-テストの落とし穴) |

### API設計

| やりたいこと | 参照先 |
|------------|-------|
| RESTful APIを設計したい | [PATTERNS.md § 5.1](./PATTERNS.md#51-restful-慣習) |
| ページネーション方式を選びたい | [PATTERNS.md § 5.2](./PATTERNS.md#52-ページネーション) |

### コードレビュー

| やりたいこと | 参照先 |
|------------|-------|
| レビュー観点を確認したい | [reviewing-code skill](../../.claude/skills/reviewing-code/SKILL.md) |
| セキュリティ観点でレビューしたい | [reviewing-code skill](../../.claude/skills/reviewing-code/SKILL.md) |

---

## 場面別チェックリスト

| タイミング | 確認項目 | 参照先 |
|----------|---------|--------|
| **設計時** | API設計、認証/認可設計 | [PATTERNS.md § 5](./PATTERNS.md#5-api設計)、[§ 1.2](./PATTERNS.md#12-認証認可) |
| **実装中** | 入力バリデーション、エラーハンドリング | [PATTERNS.md § 1.1](./PATTERNS.md#11-入力バリデーション)、[§ 3](./PATTERNS.md#3-エラーハンドリング) |
| **レビュー時** | セキュリティ、パフォーマンス、保守性 | [reviewing-code skill](../../.claude/skills/reviewing-code/SKILL.md) |
| **テスト時** | テスト戦略、カバレッジ | [PATTERNS.md § 4](./PATTERNS.md#4-テスト戦略) |
| **デプロイ前** | CORS設定、キャッシュ設定 | [PATTERNS.md § 1.3](./PATTERNS.md#13-cors設定)、[§ 2.3](./PATTERNS.md#23-キャッシュ戦略) |

---

## ファイル一覧

| ファイル | 概要 | 行数 |
|---------|-----|-----|
| **[PATTERNS.md](./PATTERNS.md)** | **Web開発の落とし穴と推奨パターン** | ~190行 |

### 関連スキル

| スキル | 概要 |
|-------|-----|
| [reviewing-code](../../.claude/skills/reviewing-code/SKILL.md) | コードレビューの構造化 |

---

## カスタマイズのヒント

このファイルはサンプルです。自分の技術スタックに合わせて以下を追加してください:

- フレームワーク固有のパターンファイル（例: REACT.md、NEXTJS.md）
- インフラ・デプロイのパターンファイル（例: DOCKER.md、CI_CD.md）
- DB固有の落とし穴ファイル（例: MYSQL.md、POSTGRES.md）
