#!/usr/bin/env bash
set -euo pipefail
# hapai/hooks/pre-tool-use/guard-pr-review.sh
# Blocks git push / gh pr merge / git merge when a PR review found unresolved issues.
# On block, automatically triggers a fresh background review so the user can fix and retry.
# Event: PreToolUse | Matcher: Bash | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Only care about Bash tool
tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Check if enabled (opt-in — requires claude CLI)
enabled="$(config_get "guardrails.pr_review.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

# Match guarded operations: git push, gh pr merge, git merge
is_guarded=0
if echo "$command" | grep -qE '(^|;|\|{1,2}|&&)\s*git\s+push\b'; then
  is_guarded=1
fi
if echo "$command" | grep -qE '(^|;|\|{1,2}|&&)\s*gh\s+pr\s+merge\b'; then
  is_guarded=1
fi
if echo "$command" | grep -qE '(^|;|\|{1,2}|&&)\s*git\s+merge\b'; then
  is_guarded=1
fi
[[ $is_guarded -eq 0 ]] && exit 0

# Check if we're in a git repo
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# Get current branch
branch="$(git_current_branch)"
[[ -z "$branch" ]] && exit 0

# Only gate if a review is scoped to this branch
review_branch="$(state_get "pr-review.branch" "")"
[[ "$review_branch" != "$branch" ]] && exit 0

# Read review status
status="$(state_get "pr-review.status" "clean")"

case "$status" in
  clean)
    allow
    ;;

  pending)
    # Check if review is stale (timed out)
    started_at="$(state_get "pr-review.started_at" "")"
    timeout_secs="$(config_get "guardrails.pr_review.review_timeout_seconds" "300")"
    is_stale=0

    if [[ -n "$started_at" ]]; then
      # Handle both GNU date (-d) and BSD date (-j -f)
      started_epoch="$(date -d "$started_at" +%s 2>/dev/null \
        || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s 2>/dev/null \
        || echo "0")"
      now_epoch="$(date +%s)"
      elapsed=$(( now_epoch - started_epoch ))
      if [[ "$elapsed" -gt "$timeout_secs" ]]; then
        is_stale=1
      fi
    fi

    if [[ "$is_stale" -eq 1 ]]; then
      state_set "pr-review.status" "clean"
      audit_log "warn" "PR review timed out for branch $branch; reset to clean"
      warn "hapai: PR review timed out (>${timeout_secs}s). Status reset to clean. Re-trigger with 'gh pr create' or 'git push -u'."
    else
      warn "hapai: PR review is still running in the background (claude-haiku). Try again shortly."
    fi
    ;;

  issues)
    # Read stored issues
    issues="$(state_get "pr-review.issues" "[]")"
    issue_count="$(echo "$issues" | jq 'length' 2>/dev/null || echo "?")"

    # Format issue list for display
    formatted="$(echo "$issues" | jq -r '.[] | "  [\(.severity)] \(.file // "?"):\(.line // "?") — \(.message // "?")"' 2>/dev/null | head -30 || echo "  (could not parse issues)")"

    # Trigger a fresh review before blocking (so user can fix and retry)
    if command -v claude &>/dev/null; then
      # Validate branch name before using in background invocation
      if [[ "$branch" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        state_set "pr-review.status" "pending"
        state_set "pr-review.started_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        nohup bash "${SCRIPT_DIR}/../_pr-review-agent.sh" "$branch" &>/dev/null &
        disown 2>/dev/null || true
      fi
    fi

    msg="hapai: PR review found ${issue_count} unresolved issue(s) on branch '${branch}'.

${formatted}

A fresh review has been started. Fix the issues and push again once it completes."

    fail_open="$(config_get "guardrails.pr_review.fail_open" "false")"
    state_increment "guard-pr-review.deny_count" 2>/dev/null || true
    audit_log "deny" "PR review blocked push: ${issue_count} issues on branch ${branch}"

    if [[ "$fail_open" == "true" ]]; then
      warn "$msg"
    else
      deny "$msg"
    fi
    ;;

  fixing)
    warn "hapai: PR review found issues — auto-fix is running in background. Try again shortly."
    ;;

  fix_clean)
    # Issues were auto-fixed; reset for next push cycle
    state_set "pr-review.status" "clean"
    state_set "pr-review.fix_attempt" "0"
    allow
    ;;

  fix_failed)
    issues="$(state_get "pr-review.issues" "[]")"
    issue_count="$(echo "$issues" | jq 'length' 2>/dev/null || echo "?")"
    formatted="$(echo "$issues" | jq -r '.[] | "  [\(.severity)] \(.file // "?"):\(.line // "?") — \(.message // "?")"' 2>/dev/null | head -30 || echo "  (could not parse issues)")"
    fix_attempts="$(state_get "pr-review.fix_attempt" "?")"

    msg="hapai: Auto-fix failed after ${fix_attempts} attempt(s). ${issue_count} issue(s) remain on branch '${branch}'.

${formatted}

Please fix the issues manually and push again."

    fail_open="$(config_get "guardrails.pr_review.fail_open" "false")"
    state_increment "guard-pr-review.deny_count" 2>/dev/null || true
    audit_log "deny" "PR fix failed: ${issue_count} issues remain on branch ${branch}"

    if [[ "$fail_open" == "true" ]]; then
      warn "$msg"
    else
      deny "$msg"
    fi
    ;;

  *)
    # Unknown status — fail open
    exit 0
    ;;
esac

allow
