# ファイル操作ガイド

シンボリックリンク環境でのknowledge/ファイル操作の詳細。

---

## シンボリックリンク環境でのgit操作

knowledge/は`$KAIZEN_KNOWLEDGE_DIR`へのシンボリックリンク。

### ファイルの削除・移動

knowledge/ のファイルを削除・移動したら、**消えた側のパスも**コミットスクリプトに渡す（渡さないと、削除がコミットに入らず作業ツリーにだけ残る）:

```bash
rm knowledge/some-topic/OLD.md
mv knowledge/some-topic/A.md knowledge/some-topic/B.md
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-knowledge-commit.sh" \
  -m "kaizen: remove OLD, rename A to B" \
  -- knowledge/some-topic/OLD.md knowledge/some-topic/A.md knowledge/some-topic/B.md
```

`git rm` / `git mv` で削除・移動してもよい。ただし、リンク元のプロジェクトからは失敗する（`knowledge/` は別リポジトリへの symlink）ので、実体ディレクトリを `-C` で指定する:

```bash
# NG: リンク元プロジェクトでは失敗する（fatal: ... is beyond a symbolic link）
git rm knowledge/some-topic/SOME_FILE.md

# OK: knowledge/ の実体ディレクトリで実行する（パスは knowledge/ からの相対）
git -C knowledge rm some-topic/SOME_FILE.md
```

`git rm` / `git mv` はその場でステージする。ステージしたまま放置すると、次に誰かがパスなしの `git commit` を打ったときに巻き込まれる。続けてコミットスクリプトに同じパスを渡して確定する。

### knowledge/ のコミット

knowledge/ は全プロジェクト・全セッションが共有する。コミットは、**自分が編集・作成・削除したファイルだけ**を明示して行う。knowledge/ を書き換えるコマンド（`/kaizen-reflect-learning`・`/kaizen-update-docs`・`/kaizen-audit-knowledge`・`/kaizen-unregister-project`・`/kaizen-init-project`）は、下のスクリプトで自動コミットする（knowledge/ が git リポジトリの場合）。手動でコミットするときも同じスクリプトを使う:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-knowledge-commit.sh" \
  -m "kaizen: <変更の要約（1行、英語）>" \
  -- knowledge/some-topic/EDITED.md knowledge/some-topic/REMOVED.md
```

- パスは、プロジェクトから見た `knowledge/...` のまま渡せる（symlink の解決はスクリプトが行う）。プロジェクトルート以外から実行するときは `--knowledge <knowledge/ の実体パス>` を付ける
- **ファイルだけを渡す**。ディレクトリは拒否される（配下にある他セッションの変更まで入るため）
- 削除・移動したファイルは、消えた側のパスも渡す（`rm` でも `git rm` / `git mv` 済みでもよい）。存在せず git も知らないパスは `skipped:` に出て、残りのパスはそのままコミットされる
- knowledge/ の外のパス（プロジェクトの `docs/` など）が 1 つでも混じると、何もステージせずに終了する（終了コード `3`）

**使わないもの**:

| 使わない | 理由 |
|---|---|
| `git add -A` / `git add .`（knowledge/ のリポジトリで） | 他セッションが編集途中のファイルまでステージし、自分のコミットとして確定する。コミットメッセージに現れない変更が履歴に入る |
| パスを付けない `git commit` | index 全体を確定する。他セッションがステージした変更も入る |

**出力の読み方**（`[kaizen-knowledge-commit]` ブロック）:

| 終了コード | `status` | 意味と対応 |
|---|---|---|
| `0` | `committed` | コミットした。`message:` の 1 行目が意図した件名か、`committed:` が渡したファイルだけかを確認する |
| `0` | `nothing` | 渡したパスに変更が無い。何もしていない |
| `0` | `skipped` | knowledge/ が git リポジトリでない（`reason=`）。何もしていない |
| `1` | `blocked` | 参照ゲートが、今回コミットする行に壊れた参照を見つけた。コミットしていない。ブロックの後ろの `MISS` 行を直して、同じコマンドを再実行する |
| `2` | `error` | git の失敗（`git:` / `failed:` の行）。knowledge/ のファイル自体は変わっていない。警告として伝え、作業は続行する |
| `3` | `error` | パス・引数の誤り（`error=`）。何もステージしていない。直して再実行する |

- `other:` の行は、今回のコミットに含めなかった他の未コミット変更（他セッションが作業中のファイルを含む）。**触らない**。あることだけをユーザーに伝える
- `gate=` は参照ゲートの結果。`passed` 以外（`skipped (python3 not found)`・`incomplete`・`not run` など）は、検査が走らなかったか完了しなかったことを表す。報告にそのまま書く

**参照ゲート**: コミットの前に、**今回コミットする行だけ**を照合する（リンク先のファイル、リンクのアンカー、「ファイル名 § 見出し」形式の参照が指す見出し）。

- 判定するのは追加・変更した行だけなので、以前からある壊れた参照ではブロックされない
- `projects/` 配下（レジストリのミラー）は対象外。python3 が無い環境では照合を飛ばし、`gate=skipped` と出す
- 意図して書いた参照（壊れた参照の例示など）でブロックされたら、ユーザーに確認したうえで `--allow-broken-refs` を付けて再実行する
- 見出しの改名や節の削除で**他のファイルからの参照が切れる**ケースは、このゲートでは検出できない。削除・移動の前に行う参照確認（`SKILL.md` の「削除・移動前チェック」）と `/kaizen-audit-knowledge` の機械チェックで拾う

---

## ファイルサイズ管理

> 詳細: `knowledge/meta/DOCUMENTATION_GUIDELINES.md`

**基準**:
- 最大800行
- 600行超で精査検討

**精査の優先順位**:
1. **第1優先**: 情報の精査（重複削除、簡潔化）
2. **第2優先**: ファイル分割（精査後も600行超の場合のみ）

**行数確認**:
```bash
wc -l knowledge/**/*.md
```

---

## バックアップ配置

knowledge/内にバックアップを作成すると全プロジェクトに影響。

```bash
# 正しい配置（プロジェクトローカル）
mkdir -p backups/$(date +%Y-%m-%d)
cp knowledge/file.md backups/$(date +%Y-%m-%d)/file.md.backup
```
