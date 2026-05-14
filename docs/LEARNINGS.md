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
