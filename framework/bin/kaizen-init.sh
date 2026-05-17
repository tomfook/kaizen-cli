#!/bin/bash
# kaizen-init.sh — Helper script for kaizen-init-project skill
# Extracts mechanical processing into a testable shell script.
#
# Usage: bash kaizen-init.sh <subcommand>
# Subcommands:
#   verify                        — Validate environment and list registries
#                                   Output includes knowledge_git=yes|no (git status of knowledge dir)
#   list-registries               — List registry names (one per line)
#   validate-registry-name <name> — Validate a registry name
#   validate-project-id <id>      — Validate a project ID (rejects generic words)
#
# Exit codes: 0=success, 1=validation/environment error, 2=usage error,
#             3=valid but generic project ID

set -euo pipefail

# Auto-detect KAIZEN_CLI_DIR from script location (bin/ -> framework/ -> repo root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KAIZEN_CLI_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- verify subcommand ---

do_verify() {
  local status="ok"
  local error=""
  local knowledge_dir=""
  local registries=""
  local template_dir="$KAIZEN_CLI_DIR/framework/templates"

  # 1. Validate KAIZEN_CLI_DIR (framework/ must exist)
  if [ ! -d "$KAIZEN_CLI_DIR/framework" ]; then
    status="error"
    error="KAIZEN_CLI_DIR is invalid: $KAIZEN_CLI_DIR/framework not found"
  fi

  # 2. Check KAIZEN_KNOWLEDGE_DIR environment variable
  if [ "$status" = "ok" ]; then
    if [ -z "${KAIZEN_KNOWLEDGE_DIR:-}" ]; then
      status="error"
      error="KAIZEN_KNOWLEDGE_DIR is not set"
    elif [ ! -d "$KAIZEN_KNOWLEDGE_DIR" ]; then
      status="error"
      error="KAIZEN_KNOWLEDGE_DIR directory does not exist: $KAIZEN_KNOWLEDGE_DIR"
    else
      knowledge_dir="$KAIZEN_KNOWLEDGE_DIR"
    fi
  fi

  # 3. List registries (subdirectories of KAIZEN_KNOWLEDGE_DIR)
  if [ "$status" = "ok" ]; then
    local reg_output
    reg_output="$(do_list_registries "$knowledge_dir")"
    if [ -n "$reg_output" ]; then
      registries="$(printf '%s' "$reg_output" | tr '\n' ',')"
    fi
  fi

  # 4. Check git status of knowledge directory
  local knowledge_git="no"
  if [ "$status" = "ok" ]; then
    if git -C "$knowledge_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      knowledge_git="yes"
    fi
  fi

  # 5. Check template directory
  if [ "$status" = "ok" ] && [ ! -d "$template_dir" ]; then
    status="error"
    error="Template directory not found: $template_dir"
  fi

  # Output structured result
  echo "[kaizen-verify]"
  echo "status=$status"
  if [ "$status" = "ok" ]; then
    echo "kaizen_cli_dir=$KAIZEN_CLI_DIR"
    echo "knowledge_dir=$knowledge_dir"
    echo "registries=$registries"
    echo "knowledge_git=$knowledge_git"
    echo "template_dir=$template_dir"
  else
    echo "error=$error"
  fi
  echo "[/kaizen-verify]"

  if [ "$status" = "error" ]; then
    return 1
  fi
  return 0
}

# --- list-registries subcommand ---

do_list_registries() {
  local knowledge_dir="${1:-${KAIZEN_KNOWLEDGE_DIR:-}}"

  if [ -z "$knowledge_dir" ]; then
    echo "Error: No knowledge directory specified and KAIZEN_KNOWLEDGE_DIR is not set" >&2
    return 1
  fi
  if [ ! -d "$knowledge_dir" ]; then
    echo "Error: Directory does not exist: $knowledge_dir" >&2
    return 1
  fi

  for entry in "$knowledge_dir"/*/; do
    [ -d "$entry" ] || continue
    basename "$entry"
  done
  return 0
}

# --- validate-registry-name subcommand ---

do_validate_registry_name() {
  local name="${1:-}"

  if [ -z "$name" ]; then
    echo "Error: Registry name is required" >&2
    return 2
  fi

  if echo "$name" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
    return 0
  else
    echo "Error: Registry name must match ^[a-z0-9][a-z0-9-]*$ (lowercase letters, numbers, hyphens; must start with letter or number)" >&2
    return 1
  fi
}

# --- validate-project-id subcommand ---

do_validate_project_id() {
  local id="${1:-}"
  local generic="tmp work project test new app dev sandbox"

  if [ -z "$id" ]; then
    echo "Error: Project ID is required" >&2
    return 2
  fi

  if ! echo "$id" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
    echo "Error: Project ID must match ^[a-z0-9][a-z0-9-]*$ (lowercase letters, numbers, hyphens; must start with letter or number)" >&2
    return 1
  fi

  for w in $generic; do
    if [ "$id" = "$w" ]; then
      echo "Warning: Project ID '$id' is too generic; choose a more descriptive name" >&2
      return 3
    fi
  done

  return 0
}

# --- Main dispatch ---

case "${1:-}" in
  verify) shift; do_verify "$@" ;;
  list-registries) shift; do_list_registries "$@" ;;
  validate-registry-name) shift; do_validate_registry_name "$@" ;;
  validate-project-id) shift; do_validate_project_id "$@" ;;
  *)
    echo "Usage: kaizen-init.sh <verify|list-registries|validate-registry-name|validate-project-id>" >&2
    exit 2
    ;;
esac
