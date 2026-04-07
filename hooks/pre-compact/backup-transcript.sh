#!/usr/bin/env bash
# hapai/hooks/pre-compact/backup-transcript.sh
# Saves the full transcript before Claude Code compacts context.
# Prevents losing conversation history on automatic or manual compaction.
# Backups are timestamped in ~/.hapai/transcripts/.
# Event: PreCompact | Timeout: 10s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Check if enabled
enabled="$(config_get "observability.backup_transcripts.enabled" "true")"
[[ "$enabled" != "true" ]] && exit 0

# Get transcript path from input
transcript_path="$(get_field '.transcript_path')"
[[ -z "$transcript_path" || ! -f "$transcript_path" ]] && exit 0

# Create backup directory
backup_dir="${HAPAI_HOME}/transcripts"
mkdir -p "$backup_dir" 2>/dev/null || exit 0

# Generate timestamped filename
timestamp="$(date +"%Y%m%d_%H%M%S")"
session_id="$(get_field '.session_id' | head -c 8)"
project_name="$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}")"
backup_file="${backup_dir}/${project_name}_${timestamp}_${session_id}.jsonl"

# Copy transcript
cp "$transcript_path" "$backup_file" 2>/dev/null || exit 0

# Get file size for logging
size="$(wc -c < "$backup_file" 2>/dev/null | tr -d ' ')"
lines="$(wc -l < "$backup_file" 2>/dev/null | tr -d ' ')"

audit_log "backup" "Transcript saved: $backup_file ($lines lines, ${size}B)"

# Cleanup old backups (keep last N days based on config)
retention_days="$(config_get "observability.backup_transcripts.retention_days" "30")"
find "$backup_dir" -name "*.jsonl" -mtime +"$retention_days" -delete 2>/dev/null || true

exit 0
