#!/usr/bin/env bash
# hapai/hooks/post-tool-use/audit-trail.sh
# Logs every tool execution to a detailed audit trail (separate from hook audit).
# Captures tool name, input summary, exit code, and timing.
# Event: PostToolUse | Matcher: (all) | Timeout: 3s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Check if enabled
enabled="$(config_get "intelligence.audit_trail.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

# Get tool details
tool_name="$(get_tool_name)"
exit_code="$(get_field '.tool_output.exit_code' 2>/dev/null || echo "")"
session_id="$(get_field '.session_id' | head -c 8)"
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
project_name="$(basename "$project_dir")"
timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")"

# Extract a summary of tool input (truncated for space)
input_summary=""
case "$tool_name" in
  Bash)
    input_summary="$(get_field '.tool_input.command' | head -c 120)"
    ;;
  Write|Edit|MultiEdit)
    input_summary="$(get_field '.tool_input.file_path' | head -c 120)"
    ;;
  Read)
    input_summary="$(get_field '.tool_input.file_path' | head -c 120)"
    ;;
  Glob)
    input_summary="$(get_field '.tool_input.pattern' | head -c 120)"
    ;;
  Grep)
    input_summary="$(get_field '.tool_input.pattern' | head -c 120)"
    ;;
  Agent)
    input_summary="$(get_field '.tool_input.description' | head -c 120)"
    ;;
  *)
    input_summary="$(echo "$_HAPAI_INPUT" | jq -r '.tool_input | keys[0:3] | join(",")' 2>/dev/null | head -c 60)"
    ;;
esac

# Write to detailed audit trail file (separate from hook audit)
audit_trail_file="${HAPAI_HOME}/audit-trail.jsonl"

{
  jq -n -c \
    --arg ts "$timestamp" \
    --arg sid "$session_id" \
    --arg tool "$tool_name" \
    --arg input "$input_summary" \
    --arg exit "$exit_code" \
    --arg project "$project_name" \
    '{ts: $ts, session: $sid, tool: $tool, input: $input, exit: $exit, project: $project}'
} >> "$audit_trail_file" 2>/dev/null || true

exit 0
