#!/usr/bin/env bash
# hapai/hooks/stop/squash-checkpoints.sh
# Consolidates checkpoint commits into a single clean commit when session ends
# Inspired by wangbooth/Claude-Code-Guardrails
# Event: Stop | Timeout: 10s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Check if auto_checkpoint with squash is enabled
enabled="$(config_get "automation.auto_checkpoint.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

squash="$(config_get "automation.auto_checkpoint.squash_on_stop" "true")"
[[ "$squash" != "true" ]] && exit 0

# Check if we're in a git repo
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# Get checkpoint prefix
prefix="$(config_get "automation.auto_checkpoint.commit_prefix" "checkpoint:")"

# Count consecutive checkpoint commits from HEAD
checkpoint_count=0
while IFS= read -r msg; do
  if echo "$msg" | grep -q "^${prefix}"; then
    checkpoint_count=$((checkpoint_count + 1))
  else
    break
  fi
done <<< "$(git log --format='%s' -50 2>/dev/null)"

# Only squash if there are 2+ checkpoints to consolidate
if [[ $checkpoint_count -lt 2 ]]; then
  exit 0
fi

# Soft reset to before the checkpoints (keeps all changes staged)
git reset --soft "HEAD~${checkpoint_count}" 2>/dev/null || exit 0

# Create a single consolidated commit
file_list="$(git diff --cached --name-only 2>/dev/null | head -10 | tr '\n' ', ' | sed 's/,$//')"
file_total="$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"

commit_msg="session: update ${file_total} files (${file_list})"
if [[ ${#commit_msg} -gt 120 ]]; then
  commit_msg="session: update ${file_total} files"
fi

git commit -m "$commit_msg" --no-verify 2>/dev/null || true

audit_log "squash" "Consolidated $checkpoint_count checkpoints into 1 commit"
exit 0
