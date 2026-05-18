# コミットメッセージフォーマット

Conventional Commits 形式のコミットメッセージ詳細リファレンス。

---

## フォーマット構造

```
type(scope): subject

body

Co-Authored-By: Claude <noreply@anthropic.com>
```

**空行**: subject と body の間、body と Co-Authored-By の間にそれぞれ空行を入れる。

---

## 各部位の役割

| 部位 | 必須 | 言語 | 説明 |
|------|------|------|------|
| type | 必須 | 英語 | 変更の種類 |
| scope | 推奨 | 英語 | 変更対象の範囲 |
| subject | 必須 | プロジェクト言語 | 「何を」変更したか端的に |
| body | 必須 | プロジェクト言語 | 「なぜ」変更したか（背景・意図） |
| Co-Authored-By | 任意（推奨） | 英語 | AI による変更の追跡用。プロジェクト規約に従う |

---

## type 一覧

| type | 用途 |
|------|------|
| `feat` | 新機能の追加 |
| `fix` | バグ修正 |
| `refactor` | 挙動を変えないコード改善 |
| `docs` | ドキュメントのみの変更 |
| `test` | テストの追加・修正 |
| `chore` | ビルド・依存・補助ツール等の雑多な変更 |
| `style` | フォーマット等、コードの意味に影響しない変更 |
| `perf` | パフォーマンス改善 |

---

## scope 例

scope は変更対象の範囲を示す。汎用的な scope は以下のとおり。プロジェクト固有の
scope（モジュール名・コンポーネント名等）はプロジェクトに応じて追加してよい。

| scope | 対象 |
|-------|------|
| `config` | 設定ファイル |
| `deps` | 依存関係 |
| `ci` | CI/CD |
| `infra` | インフラ構成 |
| `docs` | ドキュメント |
| `test` | テスト |

---

## 例文集

### feat

```
feat(api): ユーザー検索エンドポイントを追加

検索機能の要件に対応するため、名前・メールでの部分一致検索を
返す GET /users/search を実装。

Co-Authored-By: Claude <noreply@anthropic.com>
```

### fix

```
fix(query): 日付フィルタで月末データが欠落する問題を修正

WHERE句の日付比較が < だったため月末日のデータが除外されていた。
<= に変更し、月末日を含む正しい範囲でフィルタするよう修正。

Co-Authored-By: Claude <noreply@anthropic.com>
```

### refactor

```
refactor(config): 設定読み込みを単一モジュールに集約

複数箇所に分散していた環境変数の読み込みを config モジュールに
一元化し、デフォルト値の重複定義を解消。

Co-Authored-By: Claude <noreply@anthropic.com>
```

### docs

```
docs(readme): セットアップ手順に前提バージョンを追記

前提環境が不明なまま実行して失敗するケースがあったため、
README のセットアップ手順に必要バージョンを明記。

Co-Authored-By: Claude <noreply@anthropic.com>
```

### chore

```
chore(deps): テストライブラリをメジャーバージョン更新

新しいアサーション API を利用するため依存を更新。
ロックファイルも同期。

Co-Authored-By: Claude <noreply@anthropic.com>
```
