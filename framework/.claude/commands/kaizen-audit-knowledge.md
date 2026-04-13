# Audit knowledge files

knowledge/ファイルの品質監査を実施し、冗長情報の削減・SSOT違反の検出・鮮度チェックを行う。

**実行内容**:
1. knowledge/ 配下のファイルを精査
2. 削減候補・SSOT違反候補を検出
3. 監査レポートを提示し、承認された候補を反映

**使い方**:
```
/kaizen-audit-knowledge [directory]
```

ディレクトリを指定すると、その配下のみを対象とする（例: `/kaizen-audit-knowledge meta/`）。
省略時は knowledge/ 全体を対象とする。

**言語**: ユーザーの言語に合わせて応答すること

---

## 実行手順

### Step 1: knowledge/ の確認

`knowledge/` symlinkが存在するか確認する。

存在しない場合:
- 「knowledge/ symlinkが見つかりません。/kaizen-init-project でプロジェクトを初期化してください。」と表示して終了

### Step 2: kaizen-knowledge-auditor 呼び出し

Agent ツールで `kaizen-knowledge-auditor` を呼び出し、監査レポートを取得する。

プロンプトには以下を含める:
- 「knowledge/ 配下のファイルを監査し、監査レポートを作成せよ」
- `$ARGUMENTS` にディレクトリ指定がある場合: 「対象ディレクトリ: `knowledge/$ARGUMENTS`」
- knowledge/ の実体パス: `readlink -f knowledge` の結果

### Step 3: 監査レポートの提示

auditor から返却された監査レポートをユーザーに提示する。

### Step 4: ユーザー承認（必須・スキップ不可）

以下の選択肢を提示:

```markdown
監査レポートの候補について、どのように進めますか？

1. **全承認** — すべての削減候補を反映
2. **個別選択** — 候補ごとに承認/却下を選択
3. **キャンセル** — 何もしない
```

**重要**: ユーザーの明示的な承認なしに編集を実行しないこと。

### Step 5: 編集の実行

承認された候補について、まず kaizen-editing-knowledge Skill を発動する:

```xml
<invoke name="Skill">
<parameter name="skill">kaizen-editing-knowledge</parameter>
</invoke>
```

Skill 発動後、承認された各候補の削減方法に従って knowledge/ ファイルを編集する。

### Step 6: knowledge/ の自動コミット

1. `$KAIZEN_KNOWLEDGE_DIR` が git リポジトリかどうか確認:
   ```bash
   git -C "$KAIZEN_KNOWLEDGE_DIR" rev-parse --is-inside-work-tree
   ```
2. git リポジトリかつ未コミットの変更がある場合、自動コミット:
   ```bash
   git -C "$KAIZEN_KNOWLEDGE_DIR" add -A
   git -C "$KAIZEN_KNOWLEDGE_DIR" commit -m "kaizen audit: trim knowledge files"
   ```
3. git リポジトリでない場合はスキップ
4. コミットに失敗した場合、警告を表示して続行

---

## 禁止事項

| 禁止 | 理由 |
|------|------|
| ユーザー確認なしの編集実行 | 誤削除防止 |
| `$KAIZEN_CLI_DIR` 配下のファイル変更 | 配布元リポジトリを汚染 |
| kaizen-editing-knowledge Skill 発動前の編集 | チェックリスト未実施による情報損失 |

---

## 関連コマンド

| コマンド | 目的 |
|---------|------|
| `/kaizen-suggest-next` | 次のステップの提案 |
| `/kaizen-update-docs` | プロジェクトドキュメントの更新 |
| `/kaizen-reflect-learning` | knowledge/ への知見反映（追加） |
