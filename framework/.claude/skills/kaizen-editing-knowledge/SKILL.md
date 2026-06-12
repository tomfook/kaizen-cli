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

### セクション集約・圧縮時の追加チェック

ファイルを残したまま既存セクションを**集約・圧縮**（H2/H3 の統廃合・SSOT 化、内容の圧縮や別セクションへの統合）した場合、移動・削除と同等の参照陳腐化が起きる。**特に他スキルやコマンドが「ファイル名 + 行番号」で参照していると、行番号が無音で陳腐化する**。

- [ ] 集約・圧縮対象のセクション見出し名で参照を検索
  ```bash
  grep -rn '<旧見出し名>' knowledge/ .claude/skills/ .claude/commands/ .claude/agents/
  ```
- [ ] 行番号付き参照を検索（陳腐化リスク最大）
  ```bash
  grep -rnE '<旧ファイル名>.*L[0-9]+' knowledge/ .claude/skills/ .claude/commands/ .claude/agents/
  ```
- [ ] 集約対象に含まれていたキーワード（手順名・契約値・規約名等）でも検索
- [ ] ヒットした参照箇所が新しい場所（集約後のセクション or SSOT）を指すように更新済みか確認

> コミット前の最終ゲートとして [`kaizen-committing-project` § 参照陳腐化スキャン](../kaizen-committing-project/SKILL.md) でも同種の確認を行う。本セクションは編集タイミングでの細粒度チェックとして位置づけ、コミット時の漏れ拾いと併用する。

---

## 調査結果の実体確認

サブエージェント（Explore等）や Bash 出力を後段の判断材料（記録・コミット・昇格・分類）に使う場合:

- [ ] 要約だけでなく**本文を自分で Read** してから使ったか？（要約のみだと報告書に明記された情報を見落とす）
- [ ] サブエージェントの**否定的事実報告**（「knowledge/ に記載が無い」「該当ファイルは存在しない」等）を根拠に記録・コミット・昇格する前に、自分で `grep -rn` / Read して**実体確認**したか？ 否定報告は肯定報告以上に誤りやすい。特に `grep -r knowledge/` は symlink を黙って取りこぼすため `grep -rn "<kw>" "$(readlink -f knowledge)/"` で再確認する（実例: サブエージェントの「未記載」報告を信じたが実在し、誤った昇格をコミットした）。

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

---

## 関連スキル

| スキル/コマンド | 用途 |
|---------------|------|
| `kaizen-committing-project` | プロジェクトコードを git commit する際のガードレール |
