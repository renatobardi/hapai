#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-uncommitted.sh
# Warns or blocks when writing to files that have uncommitted changes.
# Prevents AI from overwriting manual work that hasn't been saved.
# Uses full relative path matching (not basename) to avoid false positives.
# Event: PreToolUse | Matcher: Write|Edit|MultiEdit | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Skip if this hook is already being orchestrated by flow-dispatcher (avoids double-logging)
_is_flow_managed && exit 0

tool_name="$(get_tool_name)"
case "$tool_name" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

# Check if enabled
enabled="$(config_get "guardrails.uncommitted_changes.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# Check if we're in a git repo
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# Get the file being written
file_path="$(get_field '.tool_input.file_path')"
[[ -z "$file_path" ]] && exit 0

# Resolve to relative path from git root for accurate matching
git_root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$git_root" ]]; then
  # Cannot determine git root — either not in a repo or corrupt state
  # Default to allowing (not in a git context, or too risky to block)
  exit 0
fi
rel_file=""

# If file_path is absolute, make it relative to git root
if [[ "$file_path" == /* ]]; then
  rel_file="${file_path#"$git_root/"}"
else
  rel_file="$file_path"
fi

# Check if the specific file (full relative path) has uncommitted changes
has_changes=0
if git diff --name-only HEAD 2>/dev/null | grep -qxF "$rel_file"; then
  has_changes=1
elif git diff --cached --name-only 2>/dev/null | grep -qxF "$rel_file"; then
  has_changes=1
fi

if [[ $has_changes -eq 1 ]]; then
  fail_open="$(config_get "guardrails.uncommitted_changes.fail_open" "true")"
  filename="$(basename "$file_path")"

  # Cooldown: escalate to fail_closed after repeated warnings
  if cooldown_active "guard-uncommitted" 2>/dev/null; then
    fail_open="false"
  fi

  if [[ "$fail_open" == "true" ]]; then
    cooldown_record "guard-uncommitted" 2>/dev/null || true
    warn "hapai: File '$filename' has uncommitted changes. Consider committing before AI modifies it."
  else
    state_increment "guard-uncommitted.deny_count"
    deny "hapai: File '$filename' has uncommitted changes. Commit your work first to avoid losing manual edits."
  fi
fi

allow
