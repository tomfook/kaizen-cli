---
name: kaizen-committing-project
description: >-
  Applied when committing project code with git.
  Must auto-activate on commit-related requests ("commit", "git commit", "/commit", "コミットして").
  Ensures Conventional Commits messages, secret scanning, symlink-safe staging,
  and registry sync before commit. Scope is the project's own repository — not knowledge/.
---

# kaizen-committing-project

プロジェクト内コードを git commit するときに毎回チェックすべき項目。

## このSkillの範囲

**含まれる情報**: コミットのたびに毎回チェックすべき項目（チェックリスト）

**含まれない情報**: コミットメッセージの詳細フォーマット（必要時に [COMMIT_FORMAT.md](COMMIT_FORMAT.md) を読む）

### 情報追加の判断基準

新しい学びをこのSkillに追加すべきか？

→ **「次回から毎回チェックすべきか？」**
- Yes → このSkillに追加
- No → [COMMIT_FORMAT.md](COMMIT_FORMAT.md) に追加

---

## 適用範囲の判定

| 変更対象 | 扱い |
|---------|------|
| プロジェクト内コード（`docs/`、ソース、設定ファイル等） | **このスキル** |
| `knowledge/`（`$KAIZEN_KNOWLEDGE_DIR` への symlink 配下） | kaizen コマンド（`/kaizen-reflect-learning`、`/kaizen-update-docs` 等）が自動コミット。手動コミットが必要な場合は `git -C "$KAIZEN_KNOWLEDGE_DIR"` を使う（→ `kaizen-editing-knowledge/FILE_OPERATIONS.md`） |

**判定方法**: ステージ対象が `knowledge/` 配下のみなら、このスキルではなく上記の kaizen コマンドまたは `git -C` を案内する。

---

## コミット前チェックリスト

- [ ] `git status` で変更対象を確認
- [ ] `git diff` で意図しない変更がないか確認
- [ ] 機密情報（`.env`、認証情報、APIキー等）がステージングに含まれていないか確認
- [ ] **symlink ガード**: `knowledge/` および `.claude/skills/` `.claude/commands/` `.claude/agents/` 配下のパスを `git add` していないか確認。これらは kaizen 側リポジトリの管理対象であり、symlink 先へステージしようとすると `fatal: ... is beyond a symbolic link` エラーになる
- [ ] 変更に `docs/PROJECT_SUMMARY.md` `docs/LEARNINGS.md` その他 `docs/` 配下が含まれる場合は、コミット前に `/kaizen-update-docs` を実行してレジストリ（`knowledge/projects/`）を同期させる。`/kaizen-update-docs` の Step 5 で同期、Step 6 で knowledge/ 側を自動コミットするため、先に通しておくこと
- [ ] **参照陳腐化スキャン**: ファイルのリネーム・移動・セクションの統合/圧縮を含む場合、参照側ドキュメントの更新漏れがないか **コミット前に必ず** `grep -rn` で横断スキャン:

  | トリガー種別 | grep 確認パターン |
  |---|---|
  | 新規追加・リネーム（ファイル/ディレクトリ） | `grep -rn '<旧名>' .` / `grep -rn '<新名>' .`（旧名・新名の両方） |
  | 既存セクションの集約・圧縮・統合・移動（見出しの統廃合） | `grep -rn '<旧見出し名>' .` / `grep -rn '<集約対象キーワード>' .` |

  **行番号付き参照を持つドキュメントは特に陳腐化しやすい**。集約・圧縮コミットでは「`ファイル名 L123` のような行番号参照」が他ファイルに残っていないか必ず確認する。編集タイミングでの細粒度チェック手順は [`kaizen-editing-knowledge` § セクション集約・圧縮時の追加チェック](../kaizen-editing-knowledge/SKILL.md) を参照。

---

## コミットメッセージ生成チェック

- [ ] type を正しく選択 → [COMMIT_FORMAT.md](COMMIT_FORMAT.md) 参照
- [ ] scope で変更対象を明示
- [ ] subject で「何を」変更したか端的に記述
- [ ] body で「なぜ」変更したかを記述（ユーザーの意図・背景）
- [ ] Co-Authored-By はプロジェクト規約に従う（推奨。規約があれば従い、なければ付与を推奨）

---

## コミット実行

- [ ] `git add` は個別ファイル指定（`git add -A` / `git add .` は使わない）
- [ ] HEREDOC 形式でコミットメッセージを渡す
- [ ] コミット後に `git status` で確認

### HEREDOC形式の例

```bash
git commit -m "$(cat <<'EOF'
feat(api): ユーザー検索エンドポイントを追加

検索機能の要件に対応するため、名前・メールでの部分一致検索を
返す GET /users/search を実装。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## 禁止事項

| 禁止 | 理由 |
|------|------|
| **body なしのコミット** | 変更の背景が不明になる |
| **`git add -A` / `git add .`** | 機密情報や不要ファイルが混入する。加えて、他セッション・他端末が並行作業中に `git mv` のステージが残っていると、別セッションの `git add -A` で意図せずリネームが巻き込まれる |
| **`git mv` 直後の宙ぶらりん放置** | 上記と同根。`git mv` を含むステージは速やかに個別 `git add <旧名> <新名>` でステージングして commit すること |
| **symlink 配下（`knowledge/` 等）のステージ** | kaizen 側リポジトリの管理対象。`git -C "$KAIZEN_KNOWLEDGE_DIR"` または kaizen コマンドを使う |
| **type の誤選択** | 変更履歴の分類が崩れる |

---

## 詳細ガイド

必要に応じて参照：

- **コミットメッセージフォーマット** → [COMMIT_FORMAT.md](COMMIT_FORMAT.md)

---

## 関連スキル

| スキル/コマンド | 用途 |
|---------------|------|
| `kaizen-editing-knowledge` | `knowledge/` や `.claude/skills/` 編集時のガードレール（symlink 環境の git 操作は同スキルの `FILE_OPERATIONS.md`） |
| `/kaizen-update-docs` | プロジェクトドキュメント更新時に発動。Step 5 でレジストリ同期、Step 6 で knowledge/ を自動コミット（コミット前に通すこと） |
