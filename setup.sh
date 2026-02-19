#!/bin/bash
set -euo pipefail

# Kaizen-CLI setup script
# Run once. Subsequent runs skip existing files.
# Use --force to re-link symlinks and update environment variables.
# Note: --force does NOT overwrite knowledge files (user data).

# --- Parse arguments ---
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    -h|--help)
      echo "Usage: bash setup.sh [--force]"
      echo ""
      echo "Options:"
      echo "  --force  Update environment variables and re-link symlinks (knowledge files are preserved)"
      echo "  -h, --help   Show this help message"
      exit 0
      ;;
  esac
done

echo "=== Kaizen-CLI Setup ==="
if [ "$FORCE" = true ]; then
  echo "(--force mode: environment variables and symlinks will be updated)"
fi
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

if [ "$FORCE" = true ]; then
  # In --force mode, reuse existing value (env var > ~/.bashrc > default)
  if [ -n "${KAIZEN_KNOWLEDGE_DIR:-}" ]; then
    echo "[2/6] Using existing KAIZEN_KNOWLEDGE_DIR: $KAIZEN_KNOWLEDGE_DIR"
  elif existing_val=$(grep -oP '^export KAIZEN_KNOWLEDGE_DIR="\K[^"]+' "$HOME/.bashrc" 2>/dev/null); then
    KAIZEN_KNOWLEDGE_DIR="$existing_val"
    echo "[2/6] Read from ~/.bashrc: KAIZEN_KNOWLEDGE_DIR=$KAIZEN_KNOWLEDGE_DIR"
  else
    echo "[2/6] Specify the path for your shared knowledge directory."
    echo "  (Press Enter to use the default)"
    read -rp "  Path [$DEFAULT_KNOWLEDGE_DIR]: " KAIZEN_KNOWLEDGE_DIR
    KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR:-$DEFAULT_KNOWLEDGE_DIR}"
    KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR/#\~/$HOME}"
  fi
else
  echo "[2/6] Specify the path for your shared knowledge directory."
  echo "  (Press Enter to use the default)"
  read -rp "  Path [$DEFAULT_KNOWLEDGE_DIR]: " KAIZEN_KNOWLEDGE_DIR
  KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR:-$DEFAULT_KNOWLEDGE_DIR}"
  # Tilde expansion
  KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR/#\~/$HOME}"
fi

if [ -d "$KAIZEN_KNOWLEDGE_DIR" ]; then
  echo "  Already exists: $KAIZEN_KNOWLEDGE_DIR (skipped)"
else
  mkdir -p "$KAIZEN_KNOWLEDGE_DIR"
  echo "  Created: $KAIZEN_KNOWLEDGE_DIR"
fi

# --- Step 2.5: Select knowledge registry ---

DEFAULT_REGISTRY="default"

if [ "$FORCE" = true ]; then
  REGISTRY_NAME="$DEFAULT_REGISTRY"
  echo "  Using registry: $REGISTRY_NAME"
else
  echo ""
  echo "  Select a knowledge registry name."
  echo "  (Registries are subdirectories of \$KAIZEN_KNOWLEDGE_DIR for isolating knowledge by context)"
  read -rp "  Registry name [$DEFAULT_REGISTRY]: " REGISTRY_NAME
  REGISTRY_NAME="${REGISTRY_NAME:-$DEFAULT_REGISTRY}"
fi

REGISTRY_DIR="$KAIZEN_KNOWLEDGE_DIR/$REGISTRY_NAME"

# --- Detect legacy structure and auto-migrate ---

if [ -d "$KAIZEN_KNOWLEDGE_DIR/meta" ] && [ ! -d "$KAIZEN_KNOWLEDGE_DIR/default" ]; then
  echo ""
  echo "  Detected legacy knowledge structure (flat layout without registries)."
  echo "  Migrating to default/ registry..."
  mkdir -p "$KAIZEN_KNOWLEDGE_DIR/default"
  for item in "$KAIZEN_KNOWLEDGE_DIR"/*/; do
    item_name="$(basename "$item")"
    if [ "$item_name" = "default" ]; then
      continue
    fi
    mv "$item" "$KAIZEN_KNOWLEDGE_DIR/default/"
    echo "  Moved: $item_name/ -> default/$item_name/"
  done
  echo "  Migration complete."

  # Fix existing project symlinks pointing to the old flat structure
  echo "  Searching for project symlinks to update..."
  fixed_count=0
  while IFS= read -r symlink; do
    target="$(readlink "$symlink")"
    if [ "$target" = "$KAIZEN_KNOWLEDGE_DIR" ]; then
      ln -sfn "$KAIZEN_KNOWLEDGE_DIR/default" "$symlink"
      echo "  Updated: $symlink -> $KAIZEN_KNOWLEDGE_DIR/default"
      fixed_count=$((fixed_count + 1))
    fi
  done < <(find "$HOME" -maxdepth 4 -name knowledge -type l 2>/dev/null)
  if [ "$fixed_count" -eq 0 ]; then
    echo "  No project symlinks needed updating."
  else
    echo "  Updated $fixed_count symlink(s)."
  fi
fi

# --- Step 3: Expand templates ---

echo ""
echo "[3/6] Expanding templates..."

# meta/
mkdir -p "$REGISTRY_DIR/meta"

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
  "$REGISTRY_DIR/meta/INDEX.md"

copy_if_not_exists "$KAIZEN_CLI_DIR/framework/knowledge/meta/GETTING_STARTED.md" \
  "$REGISTRY_DIR/meta/GETTING_STARTED.md"

copy_if_not_exists "$KAIZEN_CLI_DIR/framework/knowledge/meta/DOCUMENTATION_GUIDELINES.md" \
  "$REGISTRY_DIR/meta/DOCUMENTATION_GUIDELINES.md"

# projects/
mkdir -p "$REGISTRY_DIR/projects"

copy_if_not_exists "$KAIZEN_CLI_DIR/framework/knowledge/projects/INDEX.md.template" \
  "$REGISTRY_DIR/projects/INDEX.md"

# --- Step 4: Add environment variables to ~/.bashrc ---

echo ""
echo "[4/6] Setting environment variables..."

BASHRC="$HOME/.bashrc"

add_env_var() {
  local var_name="$1"
  local var_value="$2"
  if grep -q "^export ${var_name}=" "$BASHRC" 2>/dev/null; then
    if [ "$FORCE" = true ]; then
      sed -i "s|^export ${var_name}=.*|export ${var_name}=\"${var_value}\"|" "$BASHRC"
      echo "  Updated: export ${var_name}=\"${var_value}\" in $BASHRC"
    else
      echo "  Skipped (exists): $var_name in $BASHRC"
    fi
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
    if [ "$FORCE" = true ]; then
      ln -sf "$cmd_file" "$dest"
      echo "  Re-linked: $dest -> $cmd_file"
    else
      echo "  Skipped (exists): $dest"
    fi
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
  if [ "$FORCE" = true ]; then
    rm -f "$SKILL_DEST"
    ln -s "$SKILL_SRC" "$SKILL_DEST"
    echo "  Re-linked: $SKILL_DEST -> $SKILL_SRC"
  else
    echo "  Skipped (exists): $SKILL_DEST"
  fi
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
