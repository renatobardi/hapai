#!/usr/bin/env bash
# hapai/hooks/post-tool-use/auto-lint.sh
# Runs linter (eslint/ruff check) after Write/Edit and reports issues
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
enabled="$(config_get "automation.auto_lint.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

# Get file path
file_path="$(get_field '.tool_input.file_path')"
[[ -z "$file_path" ]] && exit 0
[[ ! -f "$file_path" ]] && exit 0

# Get file extension
ext="${file_path##*.}"
ext=".${ext}"

# Determine linter based on extension
case "$ext" in
  .py)
    linter="$(config_get "automation.auto_lint.python" "ruff check {file}")"
    ;;
  .ts|.tsx|.js|.jsx|.svelte)
    linter="$(config_get "automation.auto_lint.javascript" "eslint {file}")"
    ;;
  *)
    exit 0
    ;;
esac

# Check if linter exists
cmd_name="$(echo "$linter" | awk '{print $1}')"
if ! command -v "$cmd_name" &>/dev/null; then
  exit 0
fi

# Run linter and capture output
actual_cmd="${linter//\{file\}/$file_path}"
lint_output="$(eval "$actual_cmd" 2>&1)" || true

if [[ -n "$lint_output" ]]; then
  # Report lint issues as a system message (non-blocking)
  truncated="$(echo "$lint_output" | head -20)"
  audit_log "lint" "Issues found in $(basename "$file_path")"
  cat <<EOF
{
  "decision": "allow",
  "reason": "⚠️ hapai lint: Issues found in $(basename "$file_path"):\n$truncated"
}
EOF
  exit 0
fi

exit 0
