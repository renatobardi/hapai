#!/usr/bin/env bash
# hapai/hooks/post-tool-use/auto-format.sh
# Runs formatter (prettier/ruff) after Write/Edit operations
# Event: PostToolUse | Matcher: Write|Edit|MultiEdit | Timeout: 5s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

tool_name="$(get_tool_name)"
case "$tool_name" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

# Check if enabled
enabled="$(config_get "automation.auto_format.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

# Get file path
file_path="$(get_field '.tool_input.file_path')"
[[ -z "$file_path" ]] && exit 0
[[ ! -f "$file_path" ]] && exit 0

# Get file extension
ext="${file_path##*.}"
ext=".${ext}"

# Determine formatter based on extension
case "$ext" in
  .py)
    formatter="$(config_get "automation.auto_format.python" "ruff format {file}")"
    ;;
  .ts|.tsx|.js|.jsx|.svelte|.css|.scss|.json)
    formatter="$(config_get "automation.auto_format.javascript" "prettier --write {file}")"
    ;;
  *)
    exit 0
    ;;
esac

# Extract the command name to check if it exists
cmd_name="$(echo "$formatter" | awk '{print $1}')"
if ! command -v "$cmd_name" &>/dev/null; then
  # Formatter not installed — fail silently
  exit 0
fi

# Replace {file} placeholder and run
actual_cmd="${formatter//\{file\}/$file_path}"
eval "$actual_cmd" &>/dev/null || true

audit_log "format" "Ran: $actual_cmd"
exit 0
