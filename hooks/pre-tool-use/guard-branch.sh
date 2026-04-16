#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-branch.sh
# Blocks git commit/push/merge/rebase on protected branches (main, master, etc.)
# Event: PreToolUse | Matcher: Bash | if: Bash(git *) | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Skip if this hook is already being orchestrated by flow-dispatcher (avoids double-logging)
_is_flow_managed && exit 0

# Only care about Bash tool (defense-in-depth: 'if' filter also pre-screens)
tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Only match actual git commands, not strings containing "git" in echo/grep/comments
# Use word-boundary-aware matching: command must start with git or have git after ; | && ||
is_git_write=0
git_op=""
if echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+commit\b'; then
  is_git_write=1; git_op="commit"
elif echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+push\b'; then
  is_git_write=1; git_op="push"
elif echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+merge\b'; then
  is_git_write=1; git_op="merge"
elif echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+rebase\b'; then
  is_git_write=1; git_op="rebase"
fi

# Detect gh api branch deletion bypass (REST-layer equivalent of git push --delete)
# Covers: gh api repos/.../git/refs/heads/BRANCH -X DELETE (space-separated)
#         gh api repos/.../git/refs/heads/BRANCH -XDELETE (merged, POSIX short-option form)
#         gh api repos/.../git/refs/heads/BRANCH --method DELETE
#         gh api repos/.../git/refs/heads/BRANCH --method=DELETE
is_gh_api_branch_delete=0
gh_api_branch=""
if echo "$command" | grep -qiE '(^|;|\||&&)\s*gh\s+api\s+\S+/git/refs/heads/[^[:space:]/]+.*(-X[[:space:]]*DELETE|-XDELETE|--method[[:space:]]*DELETE|--method=DELETE)'; then
  is_gh_api_branch_delete=1
  gh_api_branch="$(echo "$command" | grep -oiE '\S+/git/refs/heads/[^[:space:]/]+' | sed -E 's|.*/git/refs/heads/([^[:space:]/"]+)|\1|' | head -1)"
fi

[[ $is_git_write -eq 0 && $is_gh_api_branch_delete -eq 0 ]] && exit 0

# Check if branch protection is enabled
enabled="$(config_get "guardrails.branch_protection.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# Block gh api deletion of protected or blocklisted branches
if [[ $is_gh_api_branch_delete -eq 1 && -n "$gh_api_branch" ]]; then
  if blocklist_check "$gh_api_branch" "branch" 2>/dev/null; then
    state_increment "guard-branch.deny_count"
    ctx="$(_build_context \
      "target_branch=$gh_api_branch" \
      "git_op=gh_api_delete" \
      "protection_type=blocklist" \
      "enforcement_method=gh_api")"
    audit_log "deny" "hapai: Branch '$gh_api_branch' is in the temporary blocklist." "$ctx"
    echo "hapai: Branch '$gh_api_branch' is in the temporary blocklist. Run 'hapai unblock $gh_api_branch' to remove." >&2
    exit 2
  fi
  if is_protected_branch "$gh_api_branch"; then
    state_increment "guard-branch.deny_count"
    ctx="$(_build_context \
      "target_branch=$gh_api_branch" \
      "git_op=gh_api_delete" \
      "protection_type=protected" \
      "enforcement_method=gh_api")"
    audit_log "deny" "hapai: Remote branch deletion blocked — '$gh_api_branch' is a protected branch." "$ctx"
    echo "hapai: Remote branch deletion blocked — '$gh_api_branch' is a protected branch. The 'gh api -X DELETE' path bypasses git hooks. Delete non-protected branches only." >&2
    exit 2
  fi
fi

# Get current branch
branch="$(git_current_branch)"

# Check temporary blocklist (e.g. hapai block "main" --type branch)
if blocklist_check "$branch" "branch" 2>/dev/null; then
  state_increment "guard-branch.deny_count"
  ctx="$(_build_context \
    "target_branch=$branch" \
    "git_op=$git_op" \
    "protection_type=blocklist" \
    "enforcement_method=git_cli")"
  deny "hapai: Branch '$branch' is in the temporary blocklist. Run 'hapai unblock $branch' to remove." "$ctx"
fi
[[ -z "$branch" ]] && exit 0

# Check if branch is protected — log rich context on each deny
if is_protected_branch "$branch"; then
  state_increment "guard-branch.deny_count"
  ctx="$(_build_context \
    "target_branch=$branch" \
    "git_op=$git_op" \
    "protection_type=protected" \
    "enforcement_method=git_cli")"

  if [[ "$git_op" == "push" ]]; then
    deny "hapai: Push blocked on protected branch '$branch'. Create a feature branch first: git checkout -b feat/your-feature" "$ctx"
  elif [[ "$git_op" == "commit" ]]; then
    deny "hapai: Commit blocked on protected branch '$branch'. Create a feature branch first: git checkout -b feat/your-feature" "$ctx"
  elif [[ "$git_op" == "merge" || "$git_op" == "rebase" ]]; then
    deny "hapai: Merge/rebase blocked on protected branch '$branch'. Use a PR workflow instead." "$ctx"
  fi
fi

allow
