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
#   check-links [project_dir]     — Compare the project's .claude/ links with the
#                                   distributed skills/commands/agents (read-only)
#   sync-links [project_dir]      — Create missing links and remove dangling ones
#                                   (idempotent; never touches non-kaizen entries)
#
# Exit codes: 0=success, 1=validation/environment error, 2=usage error,
#             3=valid but generic project ID
# Exit codes (check-links): 0=clean (foreign entries alone do not count as drift),
#             1=drift found (missing or dangling), 2=usage error,
#             3=cannot determine (project dir missing / nothing distributed)
# Exit codes (sync-links):  0=in sync after the run, 1=a link operation failed,
#             2=usage error, 3=cannot determine

set -euo pipefail

# Auto-detect KAIZEN_CLI_DIR from script location (bin/ -> framework/ -> repo root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KAIZEN_CLI_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Shared slug rule for registry names and project IDs (single source of truth)
readonly SLUG_PATTERN='^[a-z0-9][a-z0-9-]*$'
readonly SLUG_RULE="must match $SLUG_PATTERN (lowercase letters, numbers, hyphens; must start with letter or number)"

# is_valid_slug <value> — returns 0 if valid, 1 otherwise
is_valid_slug() {
  echo "$1" | grep -qE "$SLUG_PATTERN"
}

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

  if is_valid_slug "$name"; then
    return 0
  else
    echo "Error: Registry name $SLUG_RULE" >&2
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

  if ! is_valid_slug "$id"; then
    echo "Error: Project ID $SLUG_RULE" >&2
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

# --- check-links / sync-links subcommands ---
#
# Distributed items are linked into each project one by one, so a project does
# not receive items added after its last init, and keeps dangling links to items
# that were renamed or removed. Both failures are silent in Claude Code.
#
# Categories (item = <kind>/<name>, e.g. commands/kaizen-foo.md):
#   missing  — distributed, but nothing exists at the project path
#   dangling — a kaizen-* symlink in the project whose target no longer exists
#   foreign  — distributed name exists in the project but is not a link to the
#              distributed item (a copy, or a link to another location).
#              Listed for information only: copying an item is the documented
#              way to customize it, so it is neither drift nor modified.

readonly LINK_KINDS="skills commands agents"
# Linked globally by setup.sh, so it is not linked per project.
readonly GLOBAL_ONLY_SKILL="kaizen-init-project"

# list_expected <kind> — names that should exist under <project>/.claude/<kind>/
list_expected() {
  local kind="$1"
  local src="$KAIZEN_CLI_DIR/framework/.claude/$kind"
  local entry name

  [ -d "$src" ] || return 0
  for entry in "$src"/kaizen-*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    if [ "$kind" = "skills" ]; then
      [ -d "$entry" ] || continue
      [ "$name" != "$GLOBAL_ONLY_SKILL" ] || continue
    else
      [ -f "$entry" ] || continue
      case "$name" in *.md) ;; *) continue ;; esac
    fi
    echo "$name"
  done
}

# scan_links <project_dir> — fills LINKS_* globals (newline-separated lists).
# Strings instead of arrays: empty arrays break under `set -u` on bash 3.2.
scan_links() {
  local project_dir="$1"
  local kind name src dest entry

  LINKS_EXPECTED=0
  LINKS_MISSING=""
  LINKS_DANGLING=""
  LINKS_FOREIGN=""

  for kind in $LINK_KINDS; do
    src="$KAIZEN_CLI_DIR/framework/.claude/$kind"

    # Dangling: any kaizen-* symlink in the project that resolves to nothing.
    for entry in "$project_dir/.claude/$kind"/kaizen-*; do
      if [ -L "$entry" ] && [ ! -e "$entry" ]; then
        LINKS_DANGLING="${LINKS_DANGLING}${kind}/$(basename "$entry")"$'\n'
      fi
    done

    while IFS= read -r name; do
      [ -n "$name" ] || continue
      LINKS_EXPECTED=$((LINKS_EXPECTED + 1))
      dest="$project_dir/.claude/$kind/$name"
      if [ -L "$dest" ] && [ ! -e "$dest" ]; then
        :  # dangling — already recorded above
      elif [ ! -e "$dest" ]; then
        LINKS_MISSING="${LINKS_MISSING}${kind}/${name}"$'\n'
      elif [ ! -L "$dest" ] || [ ! "$dest" -ef "$src/$name" ]; then
        LINKS_FOREIGN="${LINKS_FOREIGN}${kind}/${name}"$'\n'
      fi
    done < <(list_expected "$kind")
  done
}

# count_lines <newline-separated list> — number of non-empty lines
count_lines() {
  local n=0 line
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      n=$((n + 1))
    fi
  done <<<"$1"
  echo "$n"
}

# print_items <label> <project_dir> <list> — one "<label>: <item>[ detail]" per line
print_items() {
  local label="$1" project_dir="$2" list="$3"
  local item path
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    path="$project_dir/.claude/$item"
    case "$label" in
      dangling)
        echo "$label: $item -> $(readlink "$path" 2>/dev/null || echo '?')" ;;
      foreign)
        if [ -L "$path" ]; then
          echo "$label: $item -> $(readlink "$path" 2>/dev/null || echo '?')"
        else
          echo "$label: $item (not a symlink)"
        fi ;;
      *)
        echo "$label: $item" ;;
    esac
  done <<<"$list"
}

# resolve_links_target <subcommand> [project_dir] — validates args, runs the scan.
# Sets LINKS_PROJECT_DIR. Returns 2 (usage) or 3 (cannot determine) after
# printing an error block.
resolve_links_target() {
  local sub="$1"; shift
  if [ "$#" -gt 1 ]; then
    echo "Usage: kaizen-init.sh $sub [project_dir]" >&2
    return 2
  fi

  local project_dir="${1:-$PWD}"
  local error=""
  if [ ! -d "$project_dir" ]; then
    error="project directory does not exist: $project_dir"
  else
    project_dir="$(cd "$project_dir" && pwd)"
    scan_links "$project_dir"
    if [ "$LINKS_EXPECTED" -eq 0 ]; then
      # Zero expected items means the distribution is unreadable, not "clean".
      error="no distributed kaizen-* items found under $KAIZEN_CLI_DIR/framework/.claude"
    fi
  fi

  if [ -n "$error" ]; then
    echo "[kaizen-links]"
    echo "status=error"
    echo "error=$error"
    echo "[/kaizen-links]"
    return 3
  fi
  LINKS_PROJECT_DIR="$project_dir"
  return 0
}

readonly FOREIGN_NOTE="foreign entries are customized copies or links to another location; they are left untouched (remove one and run sync-links to restore the distributed version)"

do_check_links() {
  local rc=0
  resolve_links_target check-links "$@" || rc=$?
  [ "$rc" -eq 0 ] || return "$rc"

  local project_dir="$LINKS_PROJECT_DIR"
  local n_missing n_dangling n_foreign status="clean"
  n_missing="$(count_lines "$LINKS_MISSING")"
  n_dangling="$(count_lines "$LINKS_DANGLING")"
  n_foreign="$(count_lines "$LINKS_FOREIGN")"
  if [ $((n_missing + n_dangling)) -gt 0 ]; then
    status="drift"
  fi

  echo "[kaizen-links]"
  echo "status=$status"
  echo "project_dir=$project_dir"
  echo "expected=$LINKS_EXPECTED"
  echo "missing=$n_missing"
  echo "dangling=$n_dangling"
  echo "foreign=$n_foreign"
  print_items missing "$project_dir" "$LINKS_MISSING"
  print_items dangling "$project_dir" "$LINKS_DANGLING"
  print_items foreign "$project_dir" "$LINKS_FOREIGN"
  if [ $((n_missing + n_dangling)) -gt 0 ]; then
    echo "fix=bash \"$SCRIPT_DIR/kaizen-init.sh\" sync-links \"$project_dir\""
  fi
  if [ "$n_foreign" -gt 0 ]; then
    echo "note=$FOREIGN_NOTE"
  fi
  echo "[/kaizen-links]"

  [ "$status" = "clean" ] || return 1
  return 0
}

do_sync_links() {
  local rc=0
  resolve_links_target sync-links "$@" || rc=$?
  [ "$rc" -eq 0 ] || return "$rc"

  local project_dir="$LINKS_PROJECT_DIR"
  local item path removed="" linked="" failed=""

  # 1) Remove dangling kaizen-* symlinks (re-checked right before removal).
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    path="$project_dir/.claude/$item"
    if [ -L "$path" ] && [ ! -e "$path" ]; then
      if rm -f "$path"; then
        removed="${removed}${item}"$'\n'
      else
        failed="${failed}${item}"$'\n'
      fi
    fi
  done <<<"$LINKS_DANGLING"

  # 2) Re-scan: a dangling link under a distributed name is now missing.
  scan_links "$project_dir"

  # 3) Create missing links.
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    path="$project_dir/.claude/$item"
    if mkdir -p "$(dirname "$path")" \
      && ln -s "$KAIZEN_CLI_DIR/framework/.claude/$item" "$path"; then
      linked="${linked}${item}"$'\n'
    else
      failed="${failed}${item}"$'\n'
    fi
  done <<<"$LINKS_MISSING"

  local n_linked n_removed n_foreign n_failed status="unchanged"
  n_linked="$(count_lines "$linked")"
  n_removed="$(count_lines "$removed")"
  n_foreign="$(count_lines "$LINKS_FOREIGN")"
  n_failed="$(count_lines "$failed")"
  if [ $((n_linked + n_removed)) -gt 0 ]; then
    status="synced"
  fi
  if [ "$n_failed" -gt 0 ]; then
    status="error"
  fi

  echo "[kaizen-links]"
  echo "status=$status"
  echo "project_dir=$project_dir"
  echo "expected=$LINKS_EXPECTED"
  echo "linked=$n_linked"
  echo "removed=$n_removed"
  echo "foreign=$n_foreign"
  print_items linked "$project_dir" "$linked"
  print_items removed "$project_dir" "$removed"
  print_items foreign "$project_dir" "$LINKS_FOREIGN"
  print_items failed "$project_dir" "$failed"
  if [ "$n_foreign" -gt 0 ]; then
    echo "note=$FOREIGN_NOTE"
  fi
  if [ "$n_failed" -gt 0 ]; then
    echo "error=$n_failed link operation(s) failed"
  fi
  echo "[/kaizen-links]"

  [ "$n_failed" -eq 0 ] || return 1
  return 0
}

# --- Main dispatch ---

case "${1:-}" in
  verify) shift; do_verify "$@" ;;
  list-registries) shift; do_list_registries "$@" ;;
  validate-registry-name) shift; do_validate_registry_name "$@" ;;
  validate-project-id) shift; do_validate_project_id "$@" ;;
  check-links) shift; do_check_links "$@" ;;
  sync-links) shift; do_sync_links "$@" ;;
  *)
    echo "Usage: kaizen-init.sh <verify|list-registries|validate-registry-name|validate-project-id|check-links|sync-links>" >&2
    exit 2
    ;;
esac
