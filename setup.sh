#!/bin/bash
set -euo pipefail

# Kaizen-CLI セットアップスクリプト
# 初回のみ実行。2回目以降は既存ファイルをスキップする。

echo "=== Kaizen-CLI セットアップ ==="
echo ""

# --- Step 1: KAIZEN_CLI_DIR の自動検出 ---

KAIZEN_CLI_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[1/6] KAIZEN_CLI_DIR を検出: $KAIZEN_CLI_DIR"

# framework/ ディレクトリの存在確認
if [ ! -d "$KAIZEN_CLI_DIR/framework" ]; then
  echo "エラー: $KAIZEN_CLI_DIR/framework が見つかりません。"
  echo "setup.sh は kaizen-cli リポジトリのルートから実行してください。"
  exit 1
fi

# --- Step 2: KAIZEN_KNOWLEDGE_DIR の設定 ---

DEFAULT_KNOWLEDGE_DIR="$HOME/kaizen-knowledge"
echo ""
echo "[2/6] 共有ナレッジディレクトリのパスを指定してください。"
echo "  （そのままEnterでデフォルト値を使用）"
read -rp "  パス [$DEFAULT_KNOWLEDGE_DIR]: " KAIZEN_KNOWLEDGE_DIR
KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR:-$DEFAULT_KNOWLEDGE_DIR}"

# チルダ展開
KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR/#\~/$HOME}"

if [ -d "$KAIZEN_KNOWLEDGE_DIR" ]; then
  echo "  既に存在します: $KAIZEN_KNOWLEDGE_DIR（スキップ）"
else
  mkdir -p "$KAIZEN_KNOWLEDGE_DIR"
  echo "  作成しました: $KAIZEN_KNOWLEDGE_DIR"
fi

# --- Step 3: テンプレート展開 ---

echo ""
echo "[3/6] テンプレートを展開..."

# meta/
mkdir -p "$KAIZEN_KNOWLEDGE_DIR/meta"

copy_if_not_exists() {
  local src="$1"
  local dest="$2"
  if [ -f "$dest" ]; then
    echo "  スキップ（既存）: $dest"
  else
    cp "$src" "$dest"
    echo "  作成: $dest"
  fi
}

# .template 拡張子を外してコピー
copy_if_not_exists "$KAIZEN_CLI_DIR/framework/knowledge/meta/INDEX.md.template" \
  "$KAIZEN_KNOWLEDGE_DIR/meta/INDEX.md"

copy_if_not_exists "$KAIZEN_CLI_DIR/framework/knowledge/meta/GETTING_STARTED.md" \
  "$KAIZEN_KNOWLEDGE_DIR/meta/GETTING_STARTED.md"

copy_if_not_exists "$KAIZEN_CLI_DIR/framework/knowledge/meta/DOCUMENTATION_GUIDELINES.md" \
  "$KAIZEN_KNOWLEDGE_DIR/meta/DOCUMENTATION_GUIDELINES.md"

# projects/
mkdir -p "$KAIZEN_KNOWLEDGE_DIR/projects"

copy_if_not_exists "$KAIZEN_CLI_DIR/framework/knowledge/projects/INDEX.md.template" \
  "$KAIZEN_KNOWLEDGE_DIR/projects/INDEX.md"

# --- Step 4: 環境変数を ~/.bashrc に追記 ---

echo ""
echo "[4/6] 環境変数を設定..."

BASHRC="$HOME/.bashrc"

add_env_var() {
  local var_name="$1"
  local var_value="$2"
  if grep -q "^export ${var_name}=" "$BASHRC" 2>/dev/null; then
    echo "  スキップ（既存）: $var_name in $BASHRC"
  else
    echo "" >> "$BASHRC"
    echo "# Kaizen-CLI" >> "$BASHRC"
    echo "export ${var_name}=\"${var_value}\"" >> "$BASHRC"
    echo "  追記: export ${var_name}=\"${var_value}\" → $BASHRC"
  fi
}

add_env_var "KAIZEN_CLI_DIR" "$KAIZEN_CLI_DIR"
add_env_var "KAIZEN_KNOWLEDGE_DIR" "$KAIZEN_KNOWLEDGE_DIR"

# --- Step 5: コマンドをsymlink ---

echo ""
echo "[5/6] グローバルコマンドをリンク..."

mkdir -p "$HOME/.claude/commands"

for cmd_file in "$KAIZEN_CLI_DIR/framework/.claude/commands"/kaizen-*.md; do
  cmd_name="$(basename "$cmd_file")"
  dest="$HOME/.claude/commands/$cmd_name"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "  スキップ（既存）: $dest"
  else
    ln -s "$cmd_file" "$dest"
    echo "  リンク: $dest → $cmd_file"
  fi
done

# --- Step 6: kaizen-init-project スキルをsymlink ---

echo ""
echo "[6/6] kaizen-init-project スキルをグローバルリンク..."

mkdir -p "$HOME/.claude/skills"

SKILL_SRC="$KAIZEN_CLI_DIR/framework/.claude/skills/kaizen-init-project"
SKILL_DEST="$HOME/.claude/skills/kaizen-init-project"

if [ -e "$SKILL_DEST" ] || [ -L "$SKILL_DEST" ]; then
  echo "  スキップ（既存）: $SKILL_DEST"
else
  ln -s "$SKILL_SRC" "$SKILL_DEST"
  echo "  リンク: $SKILL_DEST → $SKILL_SRC"
fi

# --- 完了 ---

echo ""
echo "=== セットアップ完了 ==="
echo ""
echo "次のステップ:"
echo "  1. source ~/.bashrc  （環境変数を反映）"
echo "  2. プロジェクトディレクトリで claude を起動"
echo "  3. /kaizen-init-project でプロジェクトを初期化"
echo ""
