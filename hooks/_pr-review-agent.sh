#!/usr/bin/env bash
set -euo pipefail
# hapai/hooks/_pr-review-agent.sh
# Background worker: runs Claude Haiku on the PR diff and writes review results to state.
# Called by pr-review-trigger.sh and guard-pr-review.sh — NOT a hook itself.
# Usage: bash _pr-review-agent.sh <branch-name>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_lib.sh"

# ─── Cleanup: reset to clean if we exit before writing a final status ────────
_review_written=0
_cleanup() {
  if [[ "$_review_written" -eq 0 ]]; then
    local current
    current="$(state_get "pr-review.status" "clean")"
    if [[ "$current" == "pending" ]]; then
      state_set "pr-review.status" "clean"
      audit_log "error" "PR review agent exited unexpectedly; reset to clean (fail-open)"
    fi
  fi
}
trap _cleanup EXIT

# ─── Validate branch argument ────────────────────────────────────────────────
branch="${1:-}"
if [[ -z "$branch" ]]; then
  audit_log "error" "PR review agent: no branch argument provided"
  exit 1
fi

# Strict validation — no shell metacharacters in branch name
if ! [[ "$branch" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
  audit_log "error" "PR review agent: invalid branch name, aborting"
  exit 1
fi

# Verify state is still scoped to this branch (guard against stale invocations)
state_branch="$(state_get "pr-review.branch" "")"
if [[ "$state_branch" != "$branch" ]]; then
  # State was overwritten by a newer review — exit silently
  exit 0
fi

# ─── Collect git diff (no user-supplied args to git) ────────────────────────
git rev-parse --is-inside-work-tree &>/dev/null || {
  state_set "pr-review.status" "clean"
  _review_written=1
  exit 0
}

# Detect base branch: config → git default → main
base_branch="$(config_get "guardrails.pr_review.base_branch" "")"
if [[ -z "$base_branch" ]]; then
  # Try to detect from origin/HEAD
  base_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||')"
fi
if [[ -z "$base_branch" ]]; then
  base_branch="main"
fi

# Validate base_branch before using in git command (prevent injection)
if ! [[ "$base_branch" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
  audit_log "error" "PR review agent: invalid base branch name, defaulting to main"
  base_branch="main"
fi

# Get diff against base branch (using symbolic refs, no user input)
diff_content="$(git diff "origin/${base_branch}...HEAD" --unified=3 2>/dev/null || true)"

if [[ -z "$diff_content" ]]; then
  # No changes relative to base — nothing to review
  state_set "pr-review.status" "clean"
  state_set "pr-review.issues" "[]"
  state_set "pr-review.summary" "No changes relative to ${base_branch}."
  _review_written=1
  audit_log "allow" "PR review: no diff against ${base_branch}, marked clean"
  exit 0
fi

# Truncate diff to max_diff_chars to control token cost
max_chars="$(config_get "guardrails.pr_review.max_diff_chars" "8000")"
if [[ "${#diff_content}" -gt "$max_chars" ]]; then
  diff_content="${diff_content:0:$max_chars}"$'\n[DIFF TRUNCATED]'
fi

# ─── Build review prompt ─────────────────────────────────────────────────────
# All user data (diff) is embedded in the variable — never passed as shell args
model="$(config_get "guardrails.pr_review.model" "claude-haiku-4-5-20251001")"

read -r -d '' review_prompt << 'PROMPT_EOF' || true
You are a code reviewer. Analyze the git diff below and identify ALL issues.

Return ONLY a valid JSON object with no other text, explanation, or markdown. Use exactly this schema:
{
  "status": "clean",
  "issues": [],
  "summary": "LGTM"
}
OR if issues were found:
{
  "status": "issues",
  "issues": [
    {
      "severity": "critical",
      "file": "path/to/file.ts",
      "line": 42,
      "message": "Concise description of the issue"
    }
  ],
  "summary": "One-line summary of findings"
}

Severity levels:
- critical: security vulnerabilities, data loss, crashes
- high: significant bugs, broken functionality, race conditions
- medium: logic errors, missing error handling, performance problems
- low: code style, dead code, unclear naming, minor improvements

Review for: bugs, security issues, error handling gaps, logic errors, and code quality.
Return "clean" only if there are genuinely no issues of any severity.

<diff>
PROMPT_EOF

# Append diff content and closing tag
full_prompt="${review_prompt}
${diff_content}
</diff>"

# ─── Invoke Claude Haiku ─────────────────────────────────────────────────────
# Pass prompt via stdin to avoid ARG_MAX limits and shell injection
tmp_prompt="$(mktemp)"
printf '%s' "$full_prompt" > "$tmp_prompt"

response=""
response="$(claude --model "$model" -p < "$tmp_prompt" 2>/dev/null)" || response=""
rm -f "$tmp_prompt"

# ─── Parse response ───────────────────────────────────────────────────────────
# Strip any markdown fences if present
response="$(echo "$response" | sed 's/^```json//; s/^```//' | sed '/^```/d')"

# Validate and extract fields (fail-open on parse errors)
review_status="$(echo "$response" | jq -r '.status // "clean"' 2>/dev/null || echo "clean")"
issues="$(echo "$response" | jq -c '.issues // []' 2>/dev/null || echo "[]")"
summary="$(echo "$response" | jq -r '.summary // ""' 2>/dev/null || echo "")"

# Validate status value
if [[ "$review_status" != "clean" && "$review_status" != "issues" ]]; then
  review_status="clean"
fi

# Validate issues is a JSON array
if ! echo "$issues" | jq -e 'type == "array"' &>/dev/null; then
  issues="[]"
fi

# If status says issues but array is empty, treat as clean
if [[ "$review_status" == "issues" ]] && [[ "$(echo "$issues" | jq 'length')" -eq 0 ]]; then
  review_status="clean"
fi

# ─── Write results to state ───────────────────────────────────────────────────
state_set "pr-review.status" "$review_status"
state_set "pr-review.issues" "$issues"
state_set "pr-review.summary" "$summary"
_review_written=1

issue_count="$(echo "$issues" | jq 'length' 2>/dev/null || echo "0")"
audit_log "allow" "PR review complete on branch ${branch}: status=${review_status}, issues=${issue_count}"

# ─── Auto-fix: launch fix agent if enabled and issues found ──────────────────
if [[ "$review_status" == "issues" ]]; then
  auto_fix_enabled="$(config_get "guardrails.pr_review.auto_fix.enabled" "false")"
  current_attempt="$(state_get "pr-review.fix_attempt" "0")"
  if [[ "$auto_fix_enabled" == "true" ]] && [[ "$current_attempt" -eq 0 ]] && command -v claude &>/dev/null; then
    if [[ "$branch" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
      state_set "pr-review.status" "fixing"
      state_set "pr-review.fix_attempt" "1"
      _review_written=1
      nohup bash "${SCRIPT_DIR}/_pr-fix-agent.sh" "$branch" "1" &>/dev/null &
      disown 2>/dev/null || true
      audit_log "allow" "PR fix agent launched for branch ${branch} (attempt 1)"
    fi
  fi
fi

exit 0
