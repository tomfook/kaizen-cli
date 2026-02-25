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

# --- Detect shell RC file ---

detect_shell_rc() {
  case "${SHELL:-/bin/bash}" in
    */zsh)
      echo "$HOME/.zshrc"
      ;;
    */bash)
      if [ "$(uname)" = "Darwin" ] && [ -f "$HOME/.bash_profile" ]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    *)
      echo "$HOME/.profile"
      ;;
  esac
}

# Search for an existing env var value across common RC files
find_env_in_rc() {
  local var_name="$1"
  for rc_file in "$SHELL_RC" "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$rc_file" ]; then
      local val
      if val=$(sed -n "s/^export ${var_name}=\"\([^\"]*\)\".*/\1/p" "$rc_file" 2>/dev/null) && [ -n "$val" ]; then
        echo "$val"
        return 0
      fi
    fi
  done
  return 1
}

SHELL_RC="$(detect_shell_rc)"

# --- Step 1: Auto-detect KAIZEN_CLI_DIR ---

KAIZEN_CLI_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "[1/5] Detected KAIZEN_CLI_DIR: $KAIZEN_CLI_DIR"

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
  # In --force mode, reuse existing value (env var > RC file > default)
  if [ -n "${KAIZEN_KNOWLEDGE_DIR:-}" ]; then
    echo "[2/5] Using existing KAIZEN_KNOWLEDGE_DIR: $KAIZEN_KNOWLEDGE_DIR"
  elif existing_val=$(find_env_in_rc "KAIZEN_KNOWLEDGE_DIR"); then
    KAIZEN_KNOWLEDGE_DIR="$existing_val"
    echo "[2/5] Read from RC file: KAIZEN_KNOWLEDGE_DIR=$KAIZEN_KNOWLEDGE_DIR"
  else
    echo "[2/5] Specify the path for your shared knowledge directory."
    echo "  (Press Enter to use the default)"
    read -rp "  Path [$DEFAULT_KNOWLEDGE_DIR]: " KAIZEN_KNOWLEDGE_DIR
    KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR:-$DEFAULT_KNOWLEDGE_DIR}"
    KAIZEN_KNOWLEDGE_DIR="${KAIZEN_KNOWLEDGE_DIR/#\~/$HOME}"
  fi
else
  echo "[2/5] Specify the path for your shared knowledge directory."
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
  # Show existing registries if any
  existing_registries=""
  if [ -d "$KAIZEN_KNOWLEDGE_DIR" ]; then
    reg_output="$(bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh" list-registries "$KAIZEN_KNOWLEDGE_DIR")" || true
    if [ -n "$reg_output" ]; then
      while IFS= read -r name; do
        if [ -z "$existing_registries" ]; then
          existing_registries="$name"
        else
          existing_registries="$existing_registries, $name"
        fi
      done <<< "$reg_output"
    fi
  fi
  if [ -n "$existing_registries" ]; then
    echo "  Existing registries: $existing_registries"
  fi
  read -rp "  Registry name [$DEFAULT_REGISTRY]: " REGISTRY_NAME
  REGISTRY_NAME="${REGISTRY_NAME:-$DEFAULT_REGISTRY}"
  if ! bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-init.sh" validate-registry-name "$REGISTRY_NAME" 2>/dev/null; then
    echo "  Error: Registry name must contain only lowercase letters, numbers, and hyphens (e.g., 'default', 'work', 'client-x')."
    exit 1
  fi
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

# --- Step 2.7: Select template language ---

LANG_CHOICE=""
if [ -f "$REGISTRY_DIR/.lang" ]; then
  # Existing registry with .lang — use stored value
  LANG_CHOICE="$(cat "$REGISTRY_DIR/.lang")"
  echo "  Using registry language: $LANG_CHOICE"
elif [ "$FORCE" = true ]; then
  # --force mode without .lang — default to en (do not prompt)
  LANG_CHOICE="en"
  echo "  Using default language: $LANG_CHOICE"
else
  # New setup — ask user
  echo ""
  echo "  Select a template language."
  read -rp "  Language (en/ja) [en]: " LANG_CHOICE
  LANG_CHOICE="${LANG_CHOICE:-en}"
  if [ "$LANG_CHOICE" != "en" ] && [ "$LANG_CHOICE" != "ja" ]; then
    echo "  Error: Language must be 'en' or 'ja'."
    exit 1
  fi
fi

# Determine template directory with fallback
TEMPLATE_DIR="$KAIZEN_CLI_DIR/framework/templates/$LANG_CHOICE"
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "  Warning: Template directory for '$LANG_CHOICE' not found. Falling back to 'en'."
  LANG_CHOICE="en"
  TEMPLATE_DIR="$KAIZEN_CLI_DIR/framework/templates/en"
fi

# Save .lang file (only if it doesn't exist yet)
if [ ! -f "$REGISTRY_DIR/.lang" ]; then
  mkdir -p "$REGISTRY_DIR"
  echo "$LANG_CHOICE" > "$REGISTRY_DIR/.lang"
  echo "  Saved language preference: $REGISTRY_DIR/.lang ($LANG_CHOICE)"
fi

# --- Step 3: Expand templates ---

echo ""
echo "[3/5] Expanding templates..."

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
copy_if_not_exists "$TEMPLATE_DIR/knowledge/meta/INDEX.md.template" \
  "$REGISTRY_DIR/meta/INDEX.md"

copy_if_not_exists "$TEMPLATE_DIR/knowledge/meta/GETTING_STARTED.md" \
  "$REGISTRY_DIR/meta/GETTING_STARTED.md"

copy_if_not_exists "$TEMPLATE_DIR/knowledge/meta/DOCUMENTATION_GUIDELINES.md" \
  "$REGISTRY_DIR/meta/DOCUMENTATION_GUIDELINES.md"

# projects/
mkdir -p "$REGISTRY_DIR/projects"

copy_if_not_exists "$TEMPLATE_DIR/knowledge/projects/INDEX.md.template" \
  "$REGISTRY_DIR/projects/INDEX.md"

# --- Step 4: Add environment variables to shell RC file ---

echo ""
echo "[4/5] Setting environment variables in $SHELL_RC ..."

# Ensure the RC file exists
touch "$SHELL_RC"

add_env_var() {
  local var_name="$1"
  local var_value="$2"
  if grep -q "^export ${var_name}=" "$SHELL_RC" 2>/dev/null; then
    if [ "$FORCE" = true ]; then
      sed -i.bak "s|^export ${var_name}=.*|export ${var_name}=\"${var_value}\"|" "$SHELL_RC" && rm -f "$SHELL_RC.bak"
      echo "  Updated: export ${var_name}=\"${var_value}\" in $SHELL_RC"
    else
      echo "  Skipped (exists): $var_name in $SHELL_RC"
    fi
  else
    echo "" >> "$SHELL_RC"
    echo "# Kaizen-CLI" >> "$SHELL_RC"
    echo "export ${var_name}=\"${var_value}\"" >> "$SHELL_RC"
    echo "  Added: export ${var_name}=\"${var_value}\" -> $SHELL_RC"
  fi
}

add_env_var "KAIZEN_CLI_DIR" "$KAIZEN_CLI_DIR"
add_env_var "KAIZEN_KNOWLEDGE_DIR" "$KAIZEN_KNOWLEDGE_DIR"

# --- Step 5: Symlink kaizen-init-project skill + migrate global commands ---

echo ""
echo "[5/5] Linking kaizen-init-project skill..."

# Migrate: remove global command symlinks from previous versions
# (commands are now project-level, created by kaizen-init-project)
migrated_count=0
for cmd_file in "$HOME/.claude/commands"/kaizen-*.md; do
  [ -e "$cmd_file" ] || [ -L "$cmd_file" ] || continue
  if [ -L "$cmd_file" ]; then
    link_target="$(readlink "$cmd_file")"
    case "$link_target" in
      */kaizen-cli/framework/.claude/commands/*)
        rm "$cmd_file"
        migrated_count=$((migrated_count + 1))
        echo "  Migrated: removed global symlink $cmd_file"
        echo "    (now created per-project by /kaizen-init-project)"
        ;;
    esac
  fi
done
if [ "$migrated_count" -gt 0 ]; then
  echo "  Removed $migrated_count global command symlink(s)."
  echo "  Run /kaizen-init-project in each project to create project-level symlinks."
fi

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
echo "  1. source $SHELL_RC    (apply environment variables)"
echo "  2. cd your-project && claude"
echo "  3. /kaizen-init-project (initialize your project)"
echo ""
