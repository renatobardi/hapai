#!/usr/bin/env bash
# hapai/hooks/post-tool-use/auto-format.sh
# Runs formatter (prettier/ruff) after Write/Edit operations.
# Uses direct invocation (no eval) to prevent command injection.
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

# Determine formatter command and args based on extension (safe, no eval)
case ".$ext" in
  .py)
    cmd_name="ruff"
    cmd_args=("format" "$file_path")
    ;;
  .ts|.tsx|.js|.jsx|.svelte|.css|.scss|.json)
    cmd_name="prettier"
    cmd_args=("--write" "$file_path")
    ;;
  *)
    exit 0
    ;;
esac

# Check if formatter exists
if ! command -v "$cmd_name" &>/dev/null; then
  # Formatter not installed — fail silently
  exit 0
fi

# Direct invocation (safe — no eval, no shell expansion on file_path)
"$cmd_name" "${cmd_args[@]}" &>/dev/null || true

audit_log "format" "Ran: $cmd_name ${cmd_args[*]}"
exit 0
