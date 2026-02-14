# ファイル操作ガイド

シンボリックリンク環境でのknowledge/ファイル操作の詳細。

---

## シンボリックリンク環境でのgit操作

knowledge/は`$KAIZEN_KNOWLEDGE_DIR`へのシンボリックリンク。

### git rm の実行方法

**重要**: knowledge/のファイル削除には`rm`ではなく`git rm`を使用する。
- `git rm`: 削除がステージングされ、コミットに含まれる
- `rm`: ファイルは削除されるが、gitの変更履歴に残らない

シンボリックリンク元のプロジェクトでは `git rm` が失敗する場合がある:

```bash
# NG: リンク元プロジェクトでは失敗する可能性がある
git rm knowledge/some-topic/SOME_FILE.md

# OK: 実体ディレクトリで実行
git -C "$KAIZEN_KNOWLEDGE_DIR" rm some-topic/SOME_FILE.md
```

### git add / commit

通常の編集は、どのプロジェクトからでも可能:

```bash
# 編集後、$KAIZEN_KNOWLEDGE_DIRでコミット（git管理している場合）
cd "$KAIZEN_KNOWLEDGE_DIR"
git add .
git commit -m "Update knowledge files"
```

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
