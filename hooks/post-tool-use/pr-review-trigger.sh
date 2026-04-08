#!/usr/bin/env bash
# hapai/hooks/post-tool-use/pr-review-trigger.sh
# Triggers a background Claude Haiku code review after 'gh pr create' or 'git push -u'.
# Sets state to pending; the background agent writes results when done.
# Event: PostToolUse | Matcher: Bash | Timeout: 5s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Only care about Bash tool
tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

# Check if enabled (opt-in — requires claude CLI)
enabled="$(config_get "guardrails.pr_review.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Only fire on successful commands
exit_code="$(get_field '.tool_output.exit_code // 0')"
[[ "$exit_code" != "0" ]] && exit 0

# Match PR creation triggers: gh pr create OR git push -u / --set-upstream
is_trigger=0
if echo "$command" | grep -qE '(^|;|\|{1,2}|&&)\s*gh\s+pr\s+create\b'; then
  is_trigger=1
fi
if echo "$command" | grep -qE '(^|;|\|{1,2}|&&)\s*git\s+push\b' \
   && echo "$command" | grep -qE '(-u\b|--set-upstream\b)'; then
  is_trigger=1
fi
[[ $is_trigger -eq 0 ]] && exit 0

# Check if we're in a git repo
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# Get current branch; skip if empty or protected
branch="$(git_current_branch)"
[[ -z "$branch" ]] && exit 0
if is_protected_branch "$branch" 2>/dev/null; then
  exit 0
fi

# Validate branch name to prevent injection
if ! [[ "$branch" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
  audit_log "error" "PR review trigger: invalid branch name '$branch', skipping"
  exit 0
fi

# Don't double-launch if a review is already pending for this branch
current_status="$(state_get "pr-review.status" "clean")"
current_branch="$(state_get "pr-review.branch" "")"
if [[ "$current_status" == "pending" && "$current_branch" == "$branch" ]]; then
  warn "hapai: PR review already running for branch '${branch}'. Waiting for results."
  exit 0
fi

# Require claude CLI
if ! command -v claude &>/dev/null; then
  warn "hapai: 'claude' CLI not found — PR review skipped. Install Claude Code to enable automatic reviews."
  exit 0
fi

# Write initial pending state
state_set "pr-review.status" "pending"
state_set "pr-review.branch" "$branch"
state_set "pr-review.started_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
state_set "pr-review.issues" "[]"

# Launch background review agent (fully detached)
agent_script="${SCRIPT_DIR}/../_pr-review-agent.sh"
nohup bash "$agent_script" "$branch" &>/dev/null &
agent_pid=$!
state_set "pr-review.agent_pid" "$agent_pid"
disown "$agent_pid" 2>/dev/null || true

audit_log "allow" "PR review triggered for branch $branch (pid=$agent_pid)"
warn "hapai: PR review started in background (claude-haiku). Subsequent pushes will be blocked until the review completes."

exit 0
