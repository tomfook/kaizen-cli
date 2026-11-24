#!/bin/bash
# kaizen-unregister.sh — Helper script for kaizen-unregister-project command
# Extracts mechanical processing into a testable shell script.
#
# Usage: bash kaizen-unregister.sh <subcommand> <registry_dir> [project-id]
# Subcommands:
#   list <registry_dir>                — List registered project IDs
#   show <registry_dir> <project-id>   — Show deletion targets for a project
#   execute <registry_dir> <project-id> — Remove project from registry
#
# execute removes the mirrors (details/<id>.md, learnings/<id>.md) and lets
# kaizen-registry.sh regenerate projects/INDEX.md. This script never edits the
# table itself: INDEX.md has one writer. The regeneration is tried with
# --dry-run first, so nothing is removed when the table cannot be rebuilt.
#
# Exit codes: 0=success, 1=validation/not-found error, 2=usage error

set -euo pipefail

# Auto-detect KAIZEN_CLI_DIR from script location (bin/ -> framework/ -> repo root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KAIZEN_CLI_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_SH="$SCRIPT_DIR/kaizen-registry.sh"

# registry_error <output of kaizen-registry.sh> — the error= text, or a fallback.
registry_error() {
  local msg
  msg="$(printf '%s\n' "$1" | sed -n 's/^error=//p' | head -n 1)"
  echo "${msg:-kaizen-registry.sh sync-index failed}"
}

# --- list subcommand ---

do_list() {
  local registry_dir="${1:-}"

  if [ -z "$registry_dir" ]; then
    echo "[kaizen-unregister-list]"
    echo "status=error"
    echo "error=Registry directory is required"
    echo "[/kaizen-unregister-list]"
    return 1
  fi

  if [ ! -d "$registry_dir" ]; then
    echo "[kaizen-unregister-list]"
    echo "status=error"
    echo "error=Registry directory does not exist: $registry_dir"
    echo "[/kaizen-unregister-list]"
    return 1
  fi

  local index_file="$registry_dir/projects/INDEX.md"
  if [ ! -f "$index_file" ]; then
    echo "[kaizen-unregister-list]"
    echo "status=error"
    echo "error=projects/INDEX.md not found in $registry_dir"
    echo "[/kaizen-unregister-list]"
    return 1
  fi

  # Parse table: skip header row (| ID) and separator row (|--), extract first column
  local projects=""
  projects=$(grep '^|' "$index_file" \
    | grep -v '^| *ID ' \
    | grep -v '^|--' \
    | awk -F'|' '{gsub(/^ +| +$/,"",$2); if ($2 != "") print $2}' \
    | tr '\n' ',' \
    | sed 's/,$//' || true)

  echo "[kaizen-unregister-list]"
  echo "status=ok"
  echo "projects=$projects"
  echo "[/kaizen-unregister-list]"
  return 0
}

# --- show subcommand ---

do_show() {
  local registry_dir="${1:-}"
  local project_id="${2:-}"

  if [ -z "$project_id" ]; then
    echo "Error: project-id is required" >&2
    return 2
  fi

  if [ -z "$registry_dir" ]; then
    echo "[kaizen-unregister-show]"
    echo "status=error"
    echo "error=Registry directory is required"
    echo "[/kaizen-unregister-show]"
    return 1
  fi

  local index_file="$registry_dir/projects/INDEX.md"
  if [ ! -f "$index_file" ]; then
    echo "[kaizen-unregister-show]"
    echo "status=error"
    echo "error=projects/INDEX.md not found in $registry_dir"
    echo "[/kaizen-unregister-show]"
    return 1
  fi

  local index_row=""
  index_row=$(grep "^| *${project_id} *|" "$index_file" || true)

  local details_file="$registry_dir/projects/details/${project_id}.md"
  local details_status="missing"
  if [ -f "$details_file" ]; then
    details_status="exists"
  fi

  local learnings_file="$registry_dir/projects/learnings/${project_id}.md"
  local learnings_status="missing"
  if [ -f "$learnings_file" ]; then
    learnings_status="exists"
  fi

  # Registered = a row in the table, or a mirror left behind without a row.
  if [ -z "$index_row" ] && [ "$details_status" = "missing" ] && [ "$learnings_status" = "missing" ]; then
    echo "[kaizen-unregister-show]"
    echo "status=error"
    echo "error=Project '${project_id}' is not registered"
    echo "[/kaizen-unregister-show]"
    return 1
  fi

  echo "[kaizen-unregister-show]"
  echo "status=ok"
  echo "index_row=$index_row"
  echo "details_file=$details_status"
  echo "learnings_file=$learnings_status"
  echo "[/kaizen-unregister-show]"
  return 0
}

# --- execute subcommand ---

do_execute() {
  local registry_dir="${1:-}"
  local project_id="${2:-}"

  if [ -z "$project_id" ]; then
    echo "Error: project-id is required" >&2
    return 2
  fi

  if [ -z "$registry_dir" ]; then
    echo "[kaizen-unregister-execute]"
    echo "status=error"
    echo "error=Registry directory is required"
    echo "[/kaizen-unregister-execute]"
    return 1
  fi

  local index_file="$registry_dir/projects/INDEX.md"
  if [ ! -f "$index_file" ]; then
    echo "[kaizen-unregister-execute]"
    echo "status=error"
    echo "error=projects/INDEX.md not found in $registry_dir"
    echo "[/kaizen-unregister-execute]"
    return 1
  fi

  local details_file="$registry_dir/projects/details/${project_id}.md"
  local learnings_file="$registry_dir/projects/learnings/${project_id}.md"

  # Registered = a row in the table, or a mirror left behind without a row.
  local had_row="no"
  if grep -q "^| *${project_id} *|" "$index_file"; then
    had_row="yes"
  fi
  if [ "$had_row" = "no" ] && [ ! -f "$details_file" ] && [ ! -f "$learnings_file" ]; then
    echo "[kaizen-unregister-execute]"
    echo "status=error"
    echo "error=Project '${project_id}' is not registered"
    echo "[/kaizen-unregister-execute]"
    return 1
  fi

  # Can the table be regenerated? Find out before anything is removed.
  local sync_out
  if ! sync_out="$(bash "$REGISTRY_SH" sync-index "$registry_dir" --drop "$project_id" --dry-run 2>&1)"; then
    echo "[kaizen-unregister-execute]"
    echo "status=error"
    echo "error=$(registry_error "$sync_out") (nothing was removed)"
    echo "[/kaizen-unregister-execute]"
    return 1
  fi

  # Remove the mirrors
  local details_removed="no"
  if [ -f "$details_file" ]; then
    rm "$details_file"
    details_removed="yes"
  fi
  local learnings_removed="no"
  if [ -f "$learnings_file" ]; then
    rm "$learnings_file"
    learnings_removed="yes"
  fi

  # Regenerate the table without the project
  if ! sync_out="$(bash "$REGISTRY_SH" sync-index "$registry_dir" --drop "$project_id" 2>&1)"; then
    echo "[kaizen-unregister-execute]"
    echo "status=error"
    echo "error=$(registry_error "$sync_out") (the mirrors were removed; run kaizen-registry.sh sync-index again)"
    echo "details_removed=$details_removed"
    echo "learnings_removed=$learnings_removed"
    echo "[/kaizen-unregister-execute]"
    return 1
  fi
  local index_removed="no"
  if [ "$had_row" = "yes" ] && ! grep -q "^| *${project_id} *|" "$index_file"; then
    index_removed="yes"
  fi

  echo "[kaizen-unregister-execute]"
  echo "status=ok"
  echo "index_removed=$index_removed"
  echo "details_removed=$details_removed"
  echo "learnings_removed=$learnings_removed"
  printf '%s\n' "$sync_out" | grep '^warning: ' || true
  echo "[/kaizen-unregister-execute]"
  return 0
}

# --- Main dispatch ---

case "${1:-}" in
  list) shift; do_list "$@" ;;
  show) shift; do_show "$@" ;;
  execute) shift; do_execute "$@" ;;
  *)
    echo "Usage: kaizen-unregister.sh <list|show|execute> <registry_dir> [project-id]" >&2
    exit 2
    ;;
esac
