#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-branch.sh
# Blocks git commit/push/merge on protected branches (main, master, etc.)
# Event: PreToolUse | Matcher: Bash | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Only care about Bash tool
tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Check if this is a git command that could modify protected branches
is_git_write=0
if echo "$command" | grep -qE 'git\s+(commit|push|merge|rebase)'; then
  is_git_write=1
fi
[[ $is_git_write -eq 0 ]] && exit 0

# Check if branch protection is enabled
enabled="$(config_get "guardrails.branch_protection.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# Get current branch
branch="$(git_current_branch)"
[[ -z "$branch" ]] && exit 0

# Check if branch is protected
if is_protected_branch "$branch"; then
  # For push, also check if pushing to a remote protected branch explicitly
  if echo "$command" | grep -qE 'git\s+push'; then
    state_increment "guard-branch.deny_count"
    deny "🛑 hapai: Push blocked on protected branch '$branch'. Create a feature branch first: git checkout -b feat/your-feature"
  fi

  if echo "$command" | grep -qE 'git\s+commit'; then
    state_increment "guard-branch.deny_count"
    deny "🛑 hapai: Commit blocked on protected branch '$branch'. Create a feature branch first: git checkout -b feat/your-feature"
  fi

  if echo "$command" | grep -qE 'git\s+(merge|rebase)'; then
    state_increment "guard-branch.deny_count"
    deny "🛑 hapai: Merge/rebase blocked on protected branch '$branch'. Use a PR workflow instead."
  fi
fi

allow
