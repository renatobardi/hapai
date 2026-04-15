#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-branch-taxonomy.sh
# Blocks creation of branches that don't follow the configured taxonomy
# Event: PreToolUse | Matcher: Bash | if: Bash(git *) | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Only intercept branch-creation operations
is_branch_create=0
if echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+checkout\s+(-b|-B)\b'; then
  is_branch_create=1
elif echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+switch\s+(-c|-C)\b'; then
  is_branch_create=1
elif echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+branch\s+[^-]'; then
  # git branch <name> (create without switch) — exclude git branch -d / -D / -m / -v etc.
  if ! echo "$command" | grep -qE 'git\s+branch\s+(-d|-D|-m|-M|--delete|--move|--list|-v|--verbose|-r|--remotes|-a|--all)'; then
    is_branch_create=1
  fi
fi
[[ $is_branch_create -eq 0 ]] && exit 0

# Check if guardrail is enabled
enabled="$(config_get "guardrails.branch_taxonomy.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# Build allowed prefixes from config
prefixes="$(config_get_list "guardrails.branch_taxonomy.allowed_prefixes")"
[[ -z "$prefixes" ]] && prefixes="feat fix chore docs refactor test perf style ci build release hotfix"
prefix_pattern="$(echo "$prefixes" | tr ' \n' '|' | sed 's/|$//')"

# Extract the branch name from the command
# Note: use [[:space:]] instead of \s for BSD sed (macOS) compatibility
branch_name=""
if echo "$command" | grep -qE 'git\s+checkout\s+(-b|-B)'; then
  branch_name="$(echo "$command" | sed -E 's/.*git[[:space:]]+checkout[[:space:]]+(-b|-B)[[:space:]]+([^ ]+).*/\2/')"
elif echo "$command" | grep -qE 'git\s+switch\s+(-c|-C)'; then
  branch_name="$(echo "$command" | sed -E 's/.*git[[:space:]]+switch[[:space:]]+(-c|-C)[[:space:]]+([^ ]+).*/\2/')"
elif echo "$command" | grep -qE 'git\s+branch\s+[^-]'; then
  branch_name="$(echo "$command" | sed -E 's/.*git[[:space:]]+branch[[:space:]]+([^ ]+).*/\1/')"
fi
[[ -z "$branch_name" ]] && exit 0

# Skip protected branches (handled by guard-branch.sh)
is_protected_branch "$branch_name" && exit 0

fail_open="$(config_get "guardrails.branch_taxonomy.fail_open" "false")"

# Validate: must match prefix/description pattern
if ! echo "$branch_name" | grep -qE "^(${prefix_pattern})/"; then
  state_increment "guard-branch-taxonomy.deny_count"
  msg="hapai: Branch '${branch_name}' must start with a valid prefix (${prefix_pattern}). Example: feat/my-feature"
  [[ "$fail_open" == "true" ]] && warn "$msg" || deny "$msg"
fi

# Validate: description after prefix/ must be non-empty and kebab-case
require_desc="$(config_get "guardrails.branch_taxonomy.require_description" "true")"
if [[ "$require_desc" == "true" ]]; then
  desc="${branch_name#*/}"
  if [[ -z "$desc" ]] || ! echo "$desc" | grep -qE '^[a-z0-9][a-z0-9._-]*$'; then
    state_increment "guard-branch-taxonomy.deny_count"
    msg="hapai: Branch description '${desc}' must be non-empty, lowercase, and use only letters, numbers, hyphens or dots. Example: feat/add-login"
    [[ "$fail_open" == "true" ]] && warn "$msg" || deny "$msg"
  fi
fi

allow
