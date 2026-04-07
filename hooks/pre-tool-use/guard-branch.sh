#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-branch.sh
# Blocks git commit/push/merge/rebase on protected branches (main, master, etc.)
# Event: PreToolUse | Matcher: Bash | if: Bash(git *) | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Only care about Bash tool (defense-in-depth: 'if' filter also pre-screens)
tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Only match actual git commands, not strings containing "git" in echo/grep/comments
# Use word-boundary-aware matching: command must start with git or have git after ; | && ||
is_git_write=0
if echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+(commit|push|merge|rebase)\b'; then
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
  if echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+push\b'; then
    state_increment "guard-branch.deny_count"
    deny "hapai: Push blocked on protected branch '$branch'. Create a feature branch first: git checkout -b feat/your-feature"
  fi

  if echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+commit\b'; then
    state_increment "guard-branch.deny_count"
    deny "hapai: Commit blocked on protected branch '$branch'. Create a feature branch first: git checkout -b feat/your-feature"
  fi

  if echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+(merge|rebase)\b'; then
    state_increment "guard-branch.deny_count"
    deny "hapai: Merge/rebase blocked on protected branch '$branch'. Use a PR workflow instead."
  fi
fi

allow
