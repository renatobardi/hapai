#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-git-workflow.sh
# Enforces trunk-based development workflow
# Event: PreToolUse | Matcher: Bash | if: Bash(git *) | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Only process git commands
echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+' || exit 0

enabled="$(config_get "guardrails.git_workflow.enabled" "false")"
[[ "$enabled" != "true" ]] && allow

model="$(config_get "guardrails.git_workflow.model" "trunk")"
fail_open="$(config_get "guardrails.git_workflow.fail_open" "true")"

# ── TRUNK-BASED ──────────────────────────────────────────────────────────────
if [[ "$model" == "trunk" ]]; then

  # Rule 1: block non-fast-forward merges (enforce rebase/squash workflow)
  if echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+merge\b'; then
    if ! echo "$command" | grep -qE 'git\s+merge\s+(--ff-only|--squash)\b'; then
      state_increment "guard-git-workflow.deny_count"
      msg="hapai: Trunk-based workflow requires --ff-only or --squash merges. Rebase your branch first: git rebase origin/main"
      [[ "$fail_open" == "true" ]] && warn "$msg" || deny "$msg"
    fi
  fi

  # Rule 2: warn on commits to branches older than max_branch_age_days
  if echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+commit\b'; then
    max_age="$(config_get "guardrails.git_workflow.trunk.max_branch_age_days" "7")"
    branch="$(git_current_branch)"
    if [[ -n "$branch" ]] && ! is_protected_branch "$branch"; then
      main_branch="$(config_get "guardrails.branch_protection.protected" "main" | tr -d '[],' | awk '{print $1}')"
      # Get timestamp of the first commit on this branch not in main
      branch_start="$(git log --format="%ct" "${main_branch}..HEAD" 2>/dev/null | tail -1)"
      if [[ -n "$branch_start" ]]; then
        now="$(date +%s)"
        age_days=$(( (now - branch_start) / 86400 ))
        if [[ $age_days -gt $max_age ]]; then
          warn "hapai: Branch '${branch}' is ${age_days} days old (limit: ${max_age}d). Consider opening a PR soon — trunk-based branches should be short-lived."
        fi
      fi
    fi
  fi

  # Rule 3: warn on push if branch is behind main
  if echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+push\b'; then
    require_up_to_date="$(config_get "guardrails.git_workflow.trunk.require_up_to_date" "true")"
    if [[ "$require_up_to_date" == "true" ]]; then
      branch="$(git_current_branch)"
      if [[ -n "$branch" ]] && ! is_protected_branch "$branch"; then
        main_branch="$(config_get "guardrails.branch_protection.protected" "main" | tr -d '[],' | awk '{print $1}')"
        behind="$(git rev-list --count "HEAD..origin/${main_branch}" 2>/dev/null || echo "0")"
        if [[ "$behind" -gt 0 ]]; then
          warn "hapai: Branch '${branch}' is ${behind} commit(s) behind '${main_branch}'. Rebase before pushing: git rebase origin/${main_branch}"
        fi
      fi
    fi
  fi

fi

allow
