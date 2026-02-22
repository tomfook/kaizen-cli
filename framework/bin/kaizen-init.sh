#!/bin/bash
# kaizen-init.sh — Helper script for kaizen-init-project skill
# Extracts mechanical processing into a testable shell script.
#
# Usage: bash kaizen-init.sh <subcommand>
# Subcommands:
#   verify           — Validate environment and list registries
#   list-registries  — List registry names (one per line)
#
# Exit codes: 0=success, 1=environment error, 2=usage error

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

  # 4. Check template directory
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

# --- Main dispatch ---

case "${1:-}" in
  verify) shift; do_verify "$@" ;;
  list-registries) shift; do_list_registries "$@" ;;
  *)
    echo "Usage: kaizen-init.sh <verify|list-registries>" >&2
    exit 2
    ;;
esac
