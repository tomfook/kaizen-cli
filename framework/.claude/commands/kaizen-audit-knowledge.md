# Audit knowledge files

knowledge/ファイルの品質監査と、プロジェクト横断教訓の昇格候補レビューを実施する。

**実行内容**:
1. `kaizen-knowledge-auditor`: knowledge/ 内部の冗長性・SSOT 違反・鮮度を精査
2. `kaizen-learning-auditor`: `knowledge/projects/learnings/` を横断スキャンし、`knowledge/` への昇格候補を提案
3. 両レポートを提示し、承認された候補を反映

**使い方**:
```
/kaizen-audit-knowledge [directory] [--scope=knowledge|learnings|all]
```

- `directory` を指定すると、その配下のみを knowledge-auditor の対象とする（例: `/kaizen-audit-knowledge meta/`）。省略時は knowledge/ 全体
- `--scope=knowledge`: learning-auditor をスキップして knowledge-auditor のみ実施
- `--scope=learnings`: knowledge-auditor をスキップして learning-auditor のみ実施
- `--scope=all`（デフォルト）: 両方実施
- `directory` が `projects/learnings/` 配下、または `projects/` の場合、knowledge-auditor の対象は通常通り絞り込むが、learning-auditor は常に `projects/learnings/` 全体を対象とする（部分監査の概念がない）

**言語**: ユーザーの言語に合わせて応答すること

---

## 実行手順

### Step 1: knowledge/ の確認

`knowledge/` symlinkが存在するか確認する。

存在しない場合:
- 「knowledge/ symlinkが見つかりません。/kaizen-init-project でプロジェクトを初期化してください。」と表示して終了

### Step 1.5: 機械チェックの実行

`framework/bin/kaizen-check-knowledge.sh` を **常に knowledge/ 全体** に対して実行する（引数を渡さない）。

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-check-knowledge.sh"
```

**全体スキャン固定の理由**: 機械チェックは安価（数秒）で、部分監査時でも他ディレクトリの鮮度警告・行数乖離を発見できるため。

**結果の振り分け**:
- 部分監査（`$ARGUMENTS` あり）: 対象ディレクトリの行のみ抜粋を Step 2 の auditor プロンプトに渡し、対象外の警告は Step 3 の「対象外の警告」セクションに保持
- 全体監査（`$ARGUMENTS` なし）: 全結果を auditor に渡す

### Step 2: kaizen-knowledge-auditor 呼び出し

`--scope=learnings` 指定時はスキップ。

Agent ツールで `kaizen-knowledge-auditor` を呼び出し、監査レポートを取得する。

プロンプトには以下を含める:
- 「knowledge/ 配下のファイルを監査し、監査レポートを作成せよ」
- `$ARGUMENTS` にディレクトリ指定がある場合: 「対象ディレクトリ: `knowledge/$ARGUMENTS`」
- knowledge/ の実体パス: `readlink -f knowledge` の結果
- Step 1.5 の機械チェック結果（該当範囲）を「【機械チェック結果】」ブロックとして添付。**この結果は確定事実として扱い、鮮度・行数・INDEX乖離の再計算を行わない**旨を明示

### Step 2.5: kaizen-learning-auditor 呼び出し

`--scope=knowledge` 指定時はスキップ。

以下のコマンドで対象ファイルの存在を確認:

```bash
ls "$(readlink -f knowledge/projects/learnings)"/*.md 2>/dev/null
```

結果が空の場合、「教訓横断レビュー: 対象ファイルなし（`knowledge/projects/learnings/` が空）」と表示してスキップ。

そうでなければ Agent ツールで `kaizen-learning-auditor` を呼び出し、教訓横断レビューを取得する。

プロンプトには以下を含める:
- 「`knowledge/projects/learnings/` を横断スキャンし、教訓横断レビューを作成せよ」
- `knowledge/projects/learnings/` の実体パス: `readlink -f knowledge/projects/learnings` の結果
- `knowledge/` の実体パス（カバレッジチェック用）: `readlink -f knowledge` の結果

**順次実行（並列ではなく逐次）**: Step 2 → Step 2.5 の順に呼ぶ。両レポートを同一コンテキストで提示する必要があり、learning-auditor は同日中の knowledge 改修を反映した状態で動作させる方が保守的なため。

### Step 3: 監査レポートの提示

両 auditor から返却されたレポートを **2 セクション** でユーザーに提示する:

```markdown
## 監査レポート（knowledge/）

[kaizen-knowledge-auditor の返却内容]

---

## 教訓横断レビュー（projects/learnings/）

[kaizen-learning-auditor の返却内容]
```

スキップした auditor のセクションは表示しない。

**性質の差を明示**: knowledge-auditor の候補は **削減・統合**（既存内容を減らす方向）が中心、learning-auditor の候補は **追加・新規セクション**（knowledge/ に内容を増やす方向）が中心であることを、ユーザー提示時に一言添えること。

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

### Step 6: AUDIT_HISTORY.md への記録

各 auditor の返却に含まれる「ログ用サマリー」ブロックを `knowledge/meta/AUDIT_HISTORY.md` に追記する。

1. `knowledge/meta/AUDIT_HISTORY.md` が存在しなければ、`framework/templates/{en,ja}/knowledge/meta/AUDIT_HISTORY.md` からコピーして作成（レジストリの言語に合わせる）
2. ファイル末尾の `**Last updated**:` / `**最終更新**:` 行の直前に、以下の順でブロックを追記:
   - まず `kaizen-knowledge-auditor` のログサマリーブロック（実行した場合）
   - 次に `kaizen-learning-auditor` のログサマリーブロック（実行した場合）
   - 両方実行した場合、**同日付・別エントリ**として 2 ブロック並べる（target が異なるので衝突しない）
3. 日付行を今日に更新
4. 個別候補の採用/却下が Step 5 で確定したら、追記した各エントリに `- **実施結果**: ...` 行を追加する。各候補を以下のタグで分類する:
   - `[採用]` / `[Adopted]`: 削減候補を反映した / 昇格候補を knowledge/ に追加した
   - `[保護]` / `[Protected]`: 削減対象から除外した / 昇格を見送った
   - `[補完]` / `[Supplemented]`: 削減ではなく追補で対応した
   - `[スコープ外]` / `[Out-of-scope]`: 今回の監査範囲外として持ち越した
   - `[過剰]` / `[Overreach]`: 候補自体が過剰反映だったため却下した

### Step 7: knowledge/ の自動コミット

1. `$KAIZEN_KNOWLEDGE_DIR` が git リポジトリかどうか確認:
   ```bash
   git -C "$KAIZEN_KNOWLEDGE_DIR" rev-parse --is-inside-work-tree
   ```
2. git リポジトリかつ未コミットの変更がある場合、自動コミット:
   ```bash
   git -C "$KAIZEN_KNOWLEDGE_DIR" add -A
   git -C "$KAIZEN_KNOWLEDGE_DIR" commit -m "kaizen audit: trim knowledge files and reflect cross-project learnings"
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
