#!/usr/bin/env bash
set -euo pipefail
# hapai/hooks/_pr-fix-agent.sh
# Background worker: auto-fixes issues found by _pr-review-agent.sh.
# Called by _pr-review-agent.sh when auto_fix is enabled.
# Usage: bash _pr-fix-agent.sh <branch-name> <attempt-number>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

# ─── Cleanup ──────────────────────────────────────────────────────────────────
_fix_written=0
_cleanup() {
  if [[ "$_fix_written" -eq 0 ]]; then
    local current
    current="$(state_get "pr-review.status" "fixing")"
    if [[ "$current" == "fixing" ]]; then
      state_set "pr-review.status" "fix_failed"
      audit_log "error" "PR fix agent exited unexpectedly; marked fix_failed"
    fi
  fi
}
trap _cleanup EXIT

# ─── Args & validation ────────────────────────────────────────────────────────
branch="${1:-}"
attempt="${2:-1}"
[[ -z "$branch" ]] && { audit_log "error" "PR fix agent: no branch argument"; exit 1; }
[[ ! "$branch" =~ ^[a-zA-Z0-9/_.-]+$ ]] && { audit_log "error" "PR fix agent: invalid branch name"; exit 1; }
[[ ! "$attempt" =~ ^[0-9]+$ ]] && attempt=1

# Exit if state is no longer scoped to this branch
state_branch="$(state_get "pr-review.branch" "")"
[[ "$state_branch" != "$branch" ]] && exit 0

# ─── Config ───────────────────────────────────────────────────────────────────
fix_model="$(config_get "guardrails.pr_review.auto_fix.model" "claude-sonnet-4-6")"
max_attempts="$(config_get "guardrails.pr_review.auto_fix.max_fix_attempts" "2")"
[[ ! "$max_attempts" =~ ^[0-9]+$ ]] && max_attempts=2

# ─── Filter issues by configured severities ───────────────────────────────────
issues="$(state_get "pr-review.issues" "[]")"

# Read severities as newline-separated list
fix_severities="$(config_get_list "guardrails.pr_review.auto_fix.severities")"
if [[ -z "$fix_severities" ]]; then
  fix_severities=$'critical\nhigh\nmedium\nlow'
fi

severity_filter="$(printf '%s' "$fix_severities" | jq -Rsc 'split("\n") | map(select(length > 0))')"
filtered_issues="$(echo "$issues" | jq -c \
  --argjson severities "$severity_filter" \
  '[.[] | select(.severity as $s | ($severities | index($s)) != null)]' \
  2>/dev/null || echo "[]")"

filtered_count="$(echo "$filtered_issues" | jq 'length' 2>/dev/null || echo "0")"
if [[ "$filtered_count" -eq 0 ]]; then
  state_set "pr-review.status" "fix_clean"
  _fix_written=1
  audit_log "allow" "PR fix: no fixable issues for branch ${branch} (severities filtered)"
  exit 0
fi

# ─── Build fix prompt ─────────────────────────────────────────────────────────
base_branch="$(config_get "guardrails.pr_review.base_branch" "")"
[[ -z "$base_branch" ]] && base_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||')" || true
[[ -z "$base_branch" ]] && base_branch="main"
[[ ! "$base_branch" =~ ^[a-zA-Z0-9._/-]+$ ]] && base_branch="main"

max_chars="$(config_get "guardrails.pr_review.max_diff_chars" "8000")"
diff_content="$(git diff "origin/${base_branch}...HEAD" --unified=3 2>/dev/null || true)"
[[ "${#diff_content}" -gt "$max_chars" ]] && diff_content="${diff_content:0:$max_chars}"$'\n[DIFF TRUNCATED]'

issues_formatted="$(echo "$filtered_issues" | jq -r \
  '.[] | "- [\(.severity)] \(.file):\(.line) — \(.message)"' 2>/dev/null || echo "")"

read -r -d '' fix_prompt << 'PROMPT_EOF' || true
You are an expert software engineer performing automated code fixes.
Below is a list of issues found in a code review, followed by the git diff.
Fix ALL listed issues by editing the relevant files in the repository.
Apply the minimum change needed to resolve each issue. Do not refactor unrelated code.
PROMPT_EOF

full_prompt="${fix_prompt}

Issues to fix (attempt ${attempt}):
${issues_formatted}

<diff>
${diff_content}
</diff>"

# ─── Invoke Claude Sonnet ─────────────────────────────────────────────────────
tmp_prompt="$(mktemp)"
printf '%s' "$full_prompt" > "$tmp_prompt"

audit_log "allow" "PR fix attempt ${attempt}/${max_attempts} on branch ${branch} (${filtered_count} issues)"
state_set "pr-review.fix_attempt" "$attempt"

claude --model "$fix_model" -p < "$tmp_prompt" &>/dev/null || true
rm -f "$tmp_prompt"

# ─── Re-review (synchronous — no nohup, we wait for result) ─────────────────
state_set "pr-review.status" "pending"
state_set "pr-review.started_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
bash "${SCRIPT_DIR}/_pr-review-agent.sh" "$branch"

# ─── Check re-review result ───────────────────────────────────────────────────
new_status="$(state_get "pr-review.status" "issues")"

if [[ "$new_status" == "clean" ]]; then
  state_set "pr-review.status" "fix_clean"
  _fix_written=1
  audit_log "allow" "PR fix succeeded (attempt ${attempt}) for branch ${branch}"
  exit 0
fi

# Issues remain — retry or exhaust
next_attempt=$((attempt + 1))
if [[ "$next_attempt" -le "$max_attempts" ]]; then
  state_set "pr-review.fix_attempt" "$next_attempt"
  exec bash "${SCRIPT_DIR}/_pr-fix-agent.sh" "$branch" "$next_attempt"
fi

# Max attempts exhausted
state_set "pr-review.status" "fix_failed"
_fix_written=1
audit_log "deny" "PR fix failed after ${max_attempts} attempt(s) on branch ${branch}"
exit 0
