#!/bin/bash
# kaizen-init.sh — Helper script for kaizen-init-project skill
# Extracts mechanical processing into a testable shell script.
#
# Usage: bash kaizen-init.sh <subcommand>
# Subcommands:
#   verify  — Validate environment and list registries
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
    local reg_list=()
    for entry in "$knowledge_dir"/*/; do
      # Skip if glob didn't match (no subdirectories)
      [ -d "$entry" ] || continue
      reg_list+=("$(basename "$entry")")
    done
    # Join with commas
    registries="$(IFS=,; echo "${reg_list[*]+"${reg_list[*]}"}")"
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

# --- Main dispatch ---

case "${1:-}" in
  verify) shift; do_verify "$@" ;;
  *)
    echo "Usage: kaizen-init.sh <verify>" >&2
    exit 2
    ;;
esac
