#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-branch-rules.sh
# Enforces branch naming conventions and origin rules.
# Rule 1 (naming): branches must use allowed prefixes and kebab-case descriptions.
# Rule 2 (origin): new branches must be created from a protected branch (main/master).
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
  # git branch <name> — exclude flag-only forms (-d, -D, -m, -v, -r, -a, etc.)
  if ! echo "$command" | grep -qE 'git\s+branch\s+(-d|-D|-m|-M|--delete|--move|--list|-v|--verbose|-r|--remotes|-a|--all)'; then
    is_branch_create=1
  fi
fi
[[ $is_branch_create -eq 0 ]] && exit 0

# Skip chained commands — cannot safely parse branch name (bail out, don't block)
if echo "$command" | grep -qE '(;|\||&&).*(git\s+(checkout|switch|branch))'; then
  exit 0
fi

# Check if enabled
enabled="$(config_get "guardrails.branch_rules.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

fail_open="$(config_get "guardrails.branch_rules.fail_open" "false")"

# ── Extract branch name from command ─────────────────────────────────────────
branch_name=""
if echo "$command" | grep -qE 'git\s+checkout\s+(-b|-B)'; then
  branch_name="$(echo "$command" | sed -E 's/.*git[[:space:]]+checkout[[:space:]]+(-b|-B)[[:space:]]+([^[:space:]]+).*/\2/')"
elif echo "$command" | grep -qE 'git\s+switch\s+(-c|-C)'; then
  branch_name="$(echo "$command" | sed -E 's/.*git[[:space:]]+switch[[:space:]]+(-c|-C)[[:space:]]+([^[:space:]]+).*/\2/')"
elif echo "$command" | grep -qE 'git\s+branch\s+[^-]'; then
  branch_name="$(echo "$command" | sed -E 's/.*git[[:space:]]+branch[[:space:]]+([^[:space:]]+).*/\1/')"
fi
[[ -z "$branch_name" ]] && exit 0

# Skip protected branches (handled by guard-branch.sh)
is_protected_branch "$branch_name" && exit 0

# ── Rule 1: naming — prefix must match allowed list ──────────────────────────
prefixes="$(config_get_list "guardrails.branch_rules.allowed_prefixes")"
[[ -z "$prefixes" ]] && prefixes="feat fix chore docs refactor test perf style ci build release hotfix"
prefix_pattern="$(echo "$prefixes" | tr ' \n' '|' | sed 's/|$//')"

if ! echo "$branch_name" | grep -qE "^(${prefix_pattern})/"; then
  state_increment "guard-branch-rules.deny_count"
  msg="hapai: Branch '${branch_name}' must start with an allowed prefix (${prefix_pattern}). Example: feat/my-feature"
  [[ "$fail_open" == "true" ]] && warn "$msg" || deny "$msg"
fi

# ── Rule 2: naming — description must be non-empty kebab-case ────────────────
require_description="$(config_get "guardrails.branch_rules.require_description" "true")"
if [[ "$require_description" == "true" ]]; then
  desc="${branch_name#*/}"
  if [[ -z "$desc" ]] || ! echo "$desc" | grep -qE '^[a-z0-9][a-z0-9._-]*$'; then
    state_increment "guard-branch-rules.deny_count"
    msg="hapai: Branch description '${desc}' must be non-empty, lowercase, and use only letters, numbers, hyphens, or dots. Example: feat/add-login"
    [[ "$fail_open" == "true" ]] && warn "$msg" || deny "$msg"
  fi
fi

# ── Rule 3: origin — must branch from a protected branch ─────────────────────
require_from_protected="$(config_get "guardrails.branch_rules.require_from_protected" "true")"
if [[ "$require_from_protected" == "true" ]]; then
  git rev-parse --is-inside-work-tree &>/dev/null || allow
  current="$(git_current_branch)"
  if [[ -n "$current" ]] && ! is_protected_branch "$current"; then
    state_increment "guard-branch-rules.deny_count"
    msg="hapai: Branches must be created from a protected branch (main/master). Currently on '${current}'. Run: git checkout main && git pull && git checkout -b ${branch_name}"
    [[ "$fail_open" == "true" ]] && warn "$msg" || deny "$msg"
  fi
fi

allow
