# Update project documentation

プロジェクト進行に伴い、プロジェクト固有ドキュメント（CLAUDE.md、docs/）の更新を支援する。

**対象**:
- `CLAUDE.md` - プロジェクト固有の必須情報
- `docs/` - プロジェクト固有の詳細情報

**対象外**: `knowledge/` — 横断知識の更新は `/kaizen-reflect-learning` で行う

**実行タイミング**: 作業完了後、ドキュメント更新が必要と感じたとき

**言語**: ユーザーの言語に合わせて応答すること

---

## 実行手順

### Step 1: 現状把握

以下を読み込んで現在の状態を把握:

1. **CLAUDE.md** を読み込み（存在する場合）
2. **docs/** ディレクトリの全ファイルを読み込み
3. **docs/PROJECT_SUMMARY.md** のYAMLフロントマターを確認

### Step 2: 作業履歴から更新候補を抽出

今日の作業履歴（Claude Codeコンテキスト）から以下を特定:

| カテゴリ | 例 |
|---------|---|
| **新たに判明した事実・仕様** | データソースの制約、API仕様、ビジネスルール |
| **意思決定の記録** | 設計判断、採用したアプローチとその理由 |
| **進捗・変更** | 完了したタスク、計画の変更 |
| **成果物の追加・更新** | 新しいファイル、モジュール、機能 |
| **用語の追加** | プロジェクト固有の略語・定義 |
| **プロジェクト固有の教訓** | 失敗したアプローチ、制約・落とし穴、次回の注意点 |

**教訓の振り分け基準**:

- **一般パターン**（プロジェクト横断で通用する知見） → `/kaizen-reflect-learning` で `knowledge/` に反映
- **プロジェクト固有**（このプロジェクトでのみ有効な教訓） → 本コマンドで `docs/LEARNINGS.md` に追記

**教訓の棚卸し**（`docs/LEARNINGS.md` が存在する場合）:

既存エントリを確認し、以下に該当するものがあれば削除を提案する:

| 状態 | 基準 | アクション |
|------|------|-----------|
| **卒業** | `knowledge/` に昇格済み | エントリ削除 |
| **陳腐化** | 制約が解消済み（ライブラリ更新、仕様変更等） | エントリ削除 |
| **内在化** | 設計・コードに反映済みで記録の意味がなくなった | エントリ削除 |

**PROJECT_SUMMARY.md 専用チェック**:

- ステータス変更があれば `status` を更新（planning → developing → released → completed、一時停止は on-hold）
- キーワードとなる技術・概念が増えた → `keywords` に追加
- 技術スタックに変更があれば「Tech Stack」セクションを更新

### Step 3: 更新提案を一括表示

以下の形式で更新提案を表示:

```markdown
## ドキュメント更新提案

### CLAUDE.md への追加/更新

**現在の行数**: XXX行
**更新後の予想行数**: XXX行

#### 追加提案:
- [セクション名]: [追加内容の要約]

#### 更新提案:
- [セクション名]: [変更内容の要約]

---

### docs/ への追加/更新

#### [ファイル名].md
- [追加/更新内容の要約]

---

### 新規作成提案（必要な場合）

#### docs/[新規ファイル名].md
- [ファイルの目的と内容の要約]

---

承認しますか？（はい / いいえ / ステップバイステップで確認）
```

### Step 4: 承認後に更新実行

ユーザーの承認を得てから更新を実行。

**PROJECT_SUMMARY.md更新時の追加処理**:

`## Project Documentation` セクションを自動更新する:
1. `docs/` ディレクトリの `.md` ファイルをスキャン
2. 各ファイルの先頭行からタイトルを抽出
3. `## Project Documentation` セクションを最新のファイル一覧で更新

形式:
```markdown
## Project Documentation

- `PROJECT_SUMMARY.md` - Project overview (this file)
- [PLAN.md](./PLAN.md) - Implementation plan
```

### Step 5: プロジェクトレジストリ同期

PROJECT_SUMMARY.md更新後、`$KAIZEN_KNOWLEDGE_DIR/projects/INDEX.md` への同期を行う。

**前提条件**: `knowledge/projects/INDEX.md` が存在すること。不在の場合はスキップ。

**注意**: `knowledge/` はシンボリンクであり、Glob ツールはシンボリンク先を辿れない。Read ツールで直接読み取ること（ファイルが存在しなければ Read がエラーを返す）。

1. PROJECT_SUMMARY.mdのYAMLフロントマターから `id`, `name`, `status`, `keywords`, `updated` を抽出
2. `knowledge/projects/INDEX.md` の一覧テーブルの該当行を更新
   - 該当IDが存在しない場合は行を追加
3. 同期結果を報告

**不在の場合**: 「projects/INDEX.md が見つかりません。スキップします。」と表示してスキップ。

### Step 6: knowledge/ の自動コミット

Step 5 で `knowledge/projects/INDEX.md` を更新した場合、変更を git にコミットする。

1. `$KAIZEN_KNOWLEDGE_DIR` が git リポジトリかどうか確認:
   ```bash
   git -C "$KAIZEN_KNOWLEDGE_DIR" rev-parse --is-inside-work-tree
   ```
2. git リポジトリかつ未コミットの変更がある場合、自動コミット:
   ```bash
   git -C "$KAIZEN_KNOWLEDGE_DIR" add -A
   git -C "$KAIZEN_KNOWLEDGE_DIR" commit -m "kaizen sync: update project registry for <project-id>"
   ```
3. git リポジトリでない場合、または Step 5 をスキップした場合はスキップ
4. コミットに失敗した場合、警告を表示して続行

---

## docs/ 推奨構成・CLAUDE.md 管理ルール

> 詳細: [knowledge/meta/DOCUMENTATION_GUIDELINES.md](knowledge/meta/DOCUMENTATION_GUIDELINES.md)

**要点**:
- CLAUDE.md: 200行以下を目安、超えたらdocs/に切り出し
- docs/PROJECT_SUMMARY.md: **必須、YAMLフロントマター必須**
- docs/その他: 計画・意思決定ログ（任意）

---

## 切り出し時の記載形式

CLAUDE.mdには参照リンクのみ残す:

```markdown
## 分析計画

> 詳細: [docs/ANALYSIS_PLAN.md](./docs/ANALYSIS_PLAN.md)
```

---

## 更新時の注意事項

1. **knowledge/は編集しない**: プロジェクト固有情報のみ対象
2. **簡潔性を維持**: 箇条書き優先、長文は避ける
3. **重複を避ける**: 同じ情報を複数ファイルに書かない
4. **SSOT**: 詳細は1箇所に集約し、他は参照リンクで誘導

---

## PROJECT_SUMMARY.md フォーマット維持ルール

PROJECT_SUMMARY.mdはプロジェクトレジストリへの登録対象。フォーマットを厳守すること。

### YAMLフロントマターの維持

**必須**: ファイル先頭のYAMLフロントマター（`---`で囲まれた部分）を維持・更新する。

```yaml
---
project:
  id: "project-id"           # 必須: 一意識別子
  name: "プロジェクト名"      # 必須: 人間可読な名前
  status: planning           # 必須: planning | developing | released | completed | on-hold
  keywords:                  # 推奨: 検索用キーワード
    - キーワード1
  created: "YYYY-MM-DD"      # 任意: 作成日
  updated: "YYYY-MM-DD"      # 任意: 更新日
---
```

### 更新時のチェックリスト

- [ ] YAMLフロントマターが存在するか確認
- [ ] `updated` 日付を更新
- [ ] ステータス変更があれば `status` を更新
- [ ] 新しいキーワードがあれば `keywords` に追加

### 標準セクション構造

以下のセクション見出しを使用（順序推奨）:

| セクション | 用途 |
|-----------|------|
| `## Purpose` | プロジェクトの目的・背景 |
| `## Overview` | 処理内容の概要 |
| `## Tech Stack` | 使用言語・フレームワーク・サービス |
| `## Design Decisions` | ADR的な判断記録 |
| `## Notes` | 運用・開発上の注意 |
| `## Project Documentation` | docs/内の全.mdファイル一覧（自動更新） |

### 禁止事項

- **YAMLフロントマターを削除しない**: 編集時も必ず維持
- **フォーマットを崩さない**: レジストリ同期に影響

---

## 関連コマンド

| コマンド | 対象 | 目的 |
|---------|------|------|
| `/kaizen-update-docs`（本コマンド） | docs/, CLAUDE.md | プロジェクトドキュメントの更新 |
| `/kaizen-reflect-learning` | knowledge/ | 横断知識への知見反映 |
| `/kaizen-suggest-next` | — | 次のステップの提案 |
