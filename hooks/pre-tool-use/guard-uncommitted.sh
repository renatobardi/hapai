#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-uncommitted.sh
# Warns when writing to files while there are uncommitted changes
# Prevents AI from overwriting manual work that hasn't been saved
# Event: PreToolUse | Matcher: Write|Edit|MultiEdit | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

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

# Check if the specific file has uncommitted changes (staged or unstaged)
if git diff --name-only HEAD 2>/dev/null | grep -qF "$(basename "$file_path")" || \
   git diff --cached --name-only 2>/dev/null | grep -qF "$(basename "$file_path")"; then

  fail_open="$(config_get "guardrails.uncommitted_changes.fail_open" "true")"

  if [[ "$fail_open" == "true" ]]; then
    warn "⚠️ hapai: File '$(basename "$file_path")' has uncommitted changes. Consider committing before AI modifies it."
  else
    state_increment "guard-uncommitted.deny_count"
    deny "🛑 hapai: File '$(basename "$file_path")' has uncommitted changes. Commit your work first to avoid losing manual edits."
  fi
fi

allow
