#!/usr/bin/env bash
# hapai/hooks/post-tool-use/auto-checkpoint.sh
# Creates precise git snapshots per file after Write/Edit (not git add .)
# Inspired by wangbooth/Claude-Code-Guardrails
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
enabled="$(config_get "automation.auto_checkpoint.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

# Check if we're in a git repo
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# Get file path
file_path="$(get_field '.tool_input.file_path')"
[[ -z "$file_path" ]] && exit 0
[[ ! -f "$file_path" ]] && exit 0

# Get commit prefix from config
prefix="$(config_get "automation.auto_checkpoint.commit_prefix" "checkpoint:")"

# Stage ONLY the specific file (not git add .)
git add "$file_path" 2>/dev/null || exit 0

# Check if there's actually something staged for this file
if git diff --cached --quiet 2>/dev/null; then
  exit 0
fi

# Create checkpoint commit with timestamp
timestamp="$(date +"%H:%M:%S")"
filename="$(basename "$file_path")"
git commit -m "${prefix} ${filename} (${timestamp})" --no-verify 2>/dev/null || true

audit_log "checkpoint" "Snapshot: $filename"
exit 0
