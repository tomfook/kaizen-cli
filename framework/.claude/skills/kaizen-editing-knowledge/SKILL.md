---
name: kaizen-editing-knowledge
description: >-
  Applied when editing files under knowledge/ or .claude/skills/.
  Must auto-activate whenever these directory paths are part of the operation.
  Provides guardrails for safe operations in symlinked environments: reference checks on delete/move, SSOT verification.
---

# kaizen-editing-knowledge

knowledge/ディレクトリやskills/編集時のチェックリスト。

## このSkillの範囲

**含まれる情報**: knowledge/やskills/のファイルを編集するたびに確認すべきチェック項目

**含まれない情報**: ファイル操作の詳細手順（必要時に参照ファイルを読む）

---

## 編集前チェック

knowledge/は`$KAIZEN_KNOWLEDGE_DIR`へのシンボリックリンク。編集すると全プロジェクトに即座に反映。
Glob ツールはシンボリンク先を辿れないため、knowledge/ 配下のファイルには Read または Grep を使用すること。

- [ ] プロジェクト固有情報を含めていないか？（一般化すること）
  - **注意**: 技術やサービス名で一般化できそうに見えても、特定プロジェクトのワークフロー内でしか使わないなら、それはプロジェクト固有情報。プロジェクトの`docs/`に配置すること。
- [ ] バックアップファイルをknowledge/内に作成していないか？（プロジェクトローカルの`backups/`に配置）
- [ ] ファイル末尾に `**Last updated**:` 行がある場合、日付を今日に更新したか？

---

## 削除・移動前チェック

### 参照確認（必須）

```bash
grep -r "FILENAME.md" knowledge/ .claude/skills/
```

- [ ] 削除対象への参照を `knowledge/` と `.claude/skills/` の両方で検索したか？
- [ ] 参照箇所を新しいリンク先に修正したか？

### 転記確認（必須）

- [ ] 削除する情報の転記先を検討したか？
- [ ] 転記が必要な場合、**転記してから削除**したか？

**禁止**: 転記確認なしの情報削除

---

## SSOT確認

- [ ] 追加する情報は既に他ファイルに存在しないか？
- [ ] 存在する場合、参照リンクで誘導する形にしたか？

---

## 禁止事項

| 禁止 | 理由 |
|------|------|
| 参照確認なしの削除・移動 | リンク切れが全プロジェクトに影響 |
| 転記確認なしの情報削除 | 情報損失 |
| knowledge/内へのバックアップ配置 | 全プロジェクトにsymlink経由で影響 |
| プロジェクト固有情報の追加 | 横断ファイルの汚染 |

---

## 詳細ガイド

- **ファイル操作（git、symlink）** → [FILE_OPERATIONS.md](FILE_OPERATIONS.md)
- **ドキュメント管理ルール** → `knowledge/meta/DOCUMENTATION_GUIDELINES.md`
