#!/usr/bin/env bash
# hapai/hooks/post-tool-use/auto-lint.sh
# Runs linter (eslint/ruff check) after Write/Edit and reports issues.
# Uses direct invocation (no eval) to prevent command injection.
# Reports via stdout JSON (not stderr, which PostToolUse may treat as error).
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

# Determine linter command and args (safe, no eval)
case ".$ext" in
  .py)
    cmd_name="ruff"
    cmd_args=("check" "$file_path")
    ;;
  .ts|.tsx|.js|.jsx|.svelte)
    cmd_name="eslint"
    cmd_args=("$file_path")
    ;;
  *)
    exit 0
    ;;
esac

# Check if linter exists
if ! command -v "$cmd_name" &>/dev/null; then
  exit 0
fi

# Run linter and capture output (direct invocation, no eval)
lint_output=""
lint_output="$("$cmd_name" "${cmd_args[@]}" 2>&1)" || true

if [[ -n "$lint_output" ]]; then
  truncated="$(echo "$lint_output" | head -20)"
  audit_log "lint" "Issues found in $(basename "$file_path")"
  # Report via warn() which uses safe JSON construction via jq
  warn "hapai lint: Issues in $(basename "$file_path"): $truncated"
fi

exit 0
