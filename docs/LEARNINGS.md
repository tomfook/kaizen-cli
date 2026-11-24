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
- **規約は社内版での適用対象を確かめてから移す** (2026-11-24): 「1 ファイル 800 行」は社内版では知識ファイル向けの目安で、スクリプトには掛かっていなかった。公開版の `CLAUDE.md` の文言を広く読んで lint と tracking issue に載せ、参照チェッカの移植で分割を迫られてから改定した（Markdown 800 行／スクリプト 1,500 行目安）
- **抽出・照合系の道具は、公開版の実物に当ててから受理書式を決める** (2026-11-24): 社内版の抽出規則のままでは、公開版の昇格先マーカー（バッククォートなしの `→` 形）とアンカー付きリンクを 1 件も拾えなかった。自リポジトリの `docs/` とテンプレートに `kaizen-check-refs.py --project . --list` を当て、SKIP に出る形を見てから規則を決める

---

### framework/.claude/ に要素を追加したら dev リポジトリ自身の .claude/ を再同期する

kaizen-cli リポジトリは自身のコマンドをドッグフーディングするため、`.claude/` に `framework/.claude/` への symlink を持つ。`framework/.claude/{skills,commands,agents}/` に新規要素を追加しても、dev リポジトリの `.claude/` 配下の symlink は自動更新されない。古いまま放置すると `/kaizen-reflect-learning` 等のサブエージェント委譲が黙って劣化する（`.claude/agents/` 不在で reflector/verifier が見つからない等）。

- 新規 skill/command/agent の追加・改名・削除後は `bash framework/bin/kaizen-init.sh sync-links` を実行する（欠落を張り、宙吊りを外す。手で `ln -s` しない）。未同期は `/kaizen-suggest-next` の冒頭でも検出される（2026-11-23, #62）
- `.claude/` に新しいサブディレクトリ（例: `agents/`）を作る場合、`.gitignore` に `/.claude/<dir>/kaizen-*` を追加する。symlink は machine 固有の絶対パスを含むためコミットしてはならない

---

### Bilingual テンプレ見出しを単一ファイルから §参照する際は英語語幹を全言語で温存する (2026-06-27)

- **状況**: NEXT_STEPS 導入(M7)で ja の DOCUMENTATION_GUIDELINES / NEXT_STEPS テンプレに `§ Design Decisions` 参照を追加した
- **問題**: ja PROJECT_SUMMARY テンプレの見出しだけ `## 設計判断` と翻訳されており、言語別に分割できない単一コマンドファイル（suggest-next/update-docs）が指す `§ Design Decisions` と文字列一致せず、ja ユーザーで散文§参照が解決しないドリフトが発生（M7で拡大）
- **教訓**: cross-ref の対象になる per-language テンプレ見出しは全言語で**英語語幹を温存**する（例: `## Design Decisions（設計判断）` / `## Auto Memory（…）の位置づけ`）。単一コマンドファイルは英語が事実上の正準アンカーになるため。audit Check 6 は `.template` 除外でこのドリフトを機械検出できない点に注意。関連: 既存「社内版移植チェックポイント § bilingual 対応」

---

### スクリプトとテストは macOS の CI でも走る — bash 3.2 と BSD 版コマンドを前提に書く (2026-11-23)

- **状況**: `.github/workflows/test.yml` は `ubuntu-latest` と `macos-latest` の両方で `bash tests/run_all.sh` を実行する。開発端末（Linux・bash 5・gawk）で通っても macOS で落ちうる
- **制約**: `set -u` 下の空配列の展開（bash 3.2 でエラー → 改行区切りの文字列で持つ）、`grep -P`、gawk 拡張（`gensub`・`\<`）、`readlink -f`、`sed -i` の引数形式を避ける。`wc -l` の出力は先頭に空白が付く
- **CI で実際に落ちた 2 件** (2026-11-24): (1) BSD awk は、読み手がパイプを閉じる（`… | head -1`）と SIGPIPE で終わらず、書き込みエラーを出して終了コード 2 を返す。awk の非ゼロ終了をそのまま失敗扱いにしない (2) bash 3.2 は `$( … )` の中に書いた `case` 文を解釈できない（構文エラー）。関数に出して、`$( )` の中は関数呼び出しだけにする
- **awk の正規表現**: グループ内の `$`（`(x|$)` の形）は処理系で扱いが分かれうるので使わない。`a ~ /…x/ || a ~ /…$/` のように条件を 2 つに分ける
- **手元での代替検査**: awk を mawk に、awk・grep・sed・find などを busybox 版に差し替えた PATH でテストを流すと、GNU 依存の一部を push 前に拾える（BSD 版そのものの検証にはならない）
- **bash 3.2 の手元検査** (2026-11-24): Docker の `bash:3.2` イメージで全テストを回せる（`docker run --rm -v "$PWD":"$PWD":ro -w "$PWD" bash:3.2 sh -c 'apk add --no-cache git python3 >/dev/null; bash tests/run_all.sh'`。リポジトリは同じ絶対パスにマウントする＝`.claude/` の symlink が絶対パスのため）。ツール類は busybox なので BSD 版の検証にはならない。`framework/bin/test-kaizen-check-knowledge.sh` の「python3 が無いときの縮退」は、このコンテナでは変更前のコードでも落ちる（環境起因。今回の合否には数えない）
