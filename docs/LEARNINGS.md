# Project Learnings

プロジェクト固有の教訓・制約・落とし穴を記録する。
汎用パターンに昇格したら `knowledge/` に移動し、ここからは削除する。

---

### 新コマンド追加時の更新対象ドキュメント

CLAUDE.md と PROJECT_SUMMARY.md だけでなく、以下も更新が必要:
- `README.md` / `README.ja.md` — コマンド一覧
- `docs/CONCEPT.md` / `docs/CONCEPT.ja.md` — コマンド紹介セクション
- `docs/QUICKSTART.md` / `docs/QUICKSTART.ja.md` — Tips セクション

---

### 社内版（00_dsci_common）からの機能移植時のチェックポイント

社内版から改善を持ち込む際に毎回繰り返し発生する判断:

- **除外**: USJ固有ドメイン情報、CodeCommit/S3 運用、業務種別固有テンプレート
- **保留**: OSS版で前提が揃っていない機能（社内版のように中央集約された前提構造が必要なものは、まず OSS版で対応するレジストリ構造を整備してから移植する）
- **置換**: prefix (`usj-` → `kaizen-`)、`context/` → `knowledge/`、環境変数 (`USJ_DSCI_COMMON_DIR` → `KAIZEN_KNOWLEDGE_DIR`)、skill参照、`git` コマンドの前提
- **レジストリ構造差分の補完**: 社内版は `ai-projects/<種別>/` で各プロジェクト固有ファイルが中央集約されているが、OSS版のレジストリは `projects/details/` のみ（PROJECT_SUMMARY コピー）で他の集約ツリーは持たない。中央集約を前提とする機能を移植する際は、対応する集約ツリー（例: `projects/learnings/`）を新設し、`kaizen-update-docs` の Step 5 に sync サブステップを追加するパターンで補完する
- **bilingual 対応**: 社内版は JA 単一だが OSS版はテンプレート/ドキュメントが EN/JA 両対応のため、grep パターンや出力は両言語を考慮する（例: `**最終更新**:` と `**Last updated**:` を両方検出する）

---

### framework/.claude/ に要素を追加したら dev リポジトリ自身の .claude/ を再同期する

kaizen-cli リポジトリは自身のコマンドをドッグフーディングするため、`.claude/` に `framework/.claude/` への symlink を持つ。`framework/.claude/{skills,commands,agents}/` に新規要素を追加しても、dev リポジトリの `.claude/` 配下の symlink は自動更新されない。古いまま放置すると `/kaizen-reflect-learning` 等のサブエージェント委譲が黙って劣化する（`.claude/agents/` 不在で reflector/verifier が見つからない等）。

- 新規 skill/command/agent 追加時は `.claude/` 配下に対応 symlink を手動追加する（または `/kaizen-init-project` を再実行）
- `.claude/` に新しいサブディレクトリ（例: `agents/`）を作る場合、`.gitignore` に `/.claude/<dir>/kaizen-*` を追加する。symlink は machine 固有の絶対パスを含むためコミットしてはならない

---

### Bilingual テンプレ見出しを単一ファイルから §参照する際は英語語幹を全言語で温存する (2026-06-27)

- **状況**: NEXT_STEPS 導入(M7)で ja の DOCUMENTATION_GUIDELINES / NEXT_STEPS テンプレに `§ Design Decisions` 参照を追加した
- **問題**: ja PROJECT_SUMMARY テンプレの見出しだけ `## 設計判断` と翻訳されており、言語別に分割できない単一コマンドファイル（suggest-next/update-docs）が指す `§ Design Decisions` と文字列一致せず、ja ユーザーで散文§参照が解決しないドリフトが発生（M7で拡大）
- **教訓**: cross-ref の対象になる per-language テンプレ見出しは全言語で**英語語幹を温存**する（例: `## Design Decisions（設計判断）` / `## Auto Memory（…）の位置づけ`）。単一コマンドファイルは英語が事実上の正準アンカーになるため。audit Check 6 は `.template` 除外でこのドリフトを機械検出できない点に注意。関連: 既存「社内版移植チェックポイント § bilingual 対応」
