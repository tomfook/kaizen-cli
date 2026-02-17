#!/bin/bash
set -euo pipefail

# Kaizen-CLI setup script
# Run once. Subsequent runs skip existing files.

echo "=== Kaizen-CLI Setup ==="
echo ""

# --- Step 1: Auto-detect KAIZEN_CLI_DIR ---

KAIZEN_CLI_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[1/6] Detected KAIZEN_CLI_DIR: $KAIZEN_CLI_DIR"

# Verify framework/ directory exists
if [ ! -d "$KAIZEN_CLI_DIR/framework" ]; then
  echo "Error: $KAIZEN_CLI_DIR/framework not found."
  echo "Please run setup.sh from the kaizen-cli repository root."
  exit 1
fi

# --- Step 2: Configure KAIZEN_KNOWLEDGE_DIR ---

DEFAULT_KNOWLEDGE_DIR="$HOME/kaizen-knowledge"
echo ""
echo "[2/6] Specify the path for your shared knowledge directory."
echo "  (Press Enter to use the default)"
read -rp "  Path [$DEFAULT_KNOWLEDGE_DIR]: " KAIZEN_KNOWLEDGE_DIR
KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR:-$DEFAULT_KNOWLEDGE_DIR}"

# Tilde expansion
KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR/#\~/$HOME}"

if [ -d "$KAIZEN_KNOWLEDGE_DIR" ]; then
  echo "  Already exists: $KAIZEN_KNOWLEDGE_DIR (skipped)"
else
  mkdir -p "$KAIZEN_KNOWLEDGE_DIR"
  echo "  Created: $KAIZEN_KNOWLEDGE_DIR"
fi

# --- Step 3: Expand templates ---

echo ""
echo "[3/6] Expanding templates..."

# meta/
mkdir -p "$KAIZEN_KNOWLEDGE_DIR/meta"

copy_if_not_exists() {
  local src="$1"
  local dest="$2"
  if [ -f "$dest" ]; then
    echo "  Skipped (exists): $dest"
  else
    cp "$src" "$dest"
    echo "  Created: $dest"
  fi
}

# Copy templates (strip .template extension)
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

# --- Step 4: Add environment variables to ~/.bashrc ---

echo ""
echo "[4/6] Setting environment variables..."

BASHRC="$HOME/.bashrc"

add_env_var() {
  local var_name="$1"
  local var_value="$2"
  if grep -q "^export ${var_name}=" "$BASHRC" 2>/dev/null; then
    echo "  Skipped (exists): $var_name in $BASHRC"
  else
    echo "" >> "$BASHRC"
    echo "# Kaizen-CLI" >> "$BASHRC"
    echo "export ${var_name}=\"${var_value}\"" >> "$BASHRC"
    echo "  Added: export ${var_name}=\"${var_value}\" -> $BASHRC"
  fi
}

add_env_var "KAIZEN_CLI_DIR" "$KAIZEN_CLI_DIR"
add_env_var "KAIZEN_KNOWLEDGE_DIR" "$KAIZEN_KNOWLEDGE_DIR"

# --- Step 5: Symlink global commands ---

echo ""
echo "[5/6] Linking global commands..."

mkdir -p "$HOME/.claude/commands"

for cmd_file in "$KAIZEN_CLI_DIR/framework/.claude/commands"/kaizen-*.md; do
  cmd_name="$(basename "$cmd_file")"
  dest="$HOME/.claude/commands/$cmd_name"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "  Skipped (exists): $dest"
  else
    ln -s "$cmd_file" "$dest"
    echo "  Linked: $dest -> $cmd_file"
  fi
done

# --- Step 6: Symlink kaizen-init-project skill ---

echo ""
echo "[6/6] Linking kaizen-init-project skill..."

mkdir -p "$HOME/.claude/skills"

SKILL_SRC="$KAIZEN_CLI_DIR/framework/.claude/skills/kaizen-init-project"
SKILL_DEST="$HOME/.claude/skills/kaizen-init-project"

if [ -e "$SKILL_DEST" ] || [ -L "$SKILL_DEST" ]; then
  echo "  Skipped (exists): $SKILL_DEST"
else
  ln -s "$SKILL_SRC" "$SKILL_DEST"
  echo "  Linked: $SKILL_DEST -> $SKILL_SRC"
fi

# --- Done ---

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. source ~/.bashrc    (apply environment variables)"
echo "  2. cd your-project && claude"
echo "  3. /kaizen-init-project (initialize your project)"
echo ""
