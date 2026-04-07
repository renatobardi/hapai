#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-destructive.sh
# Blocks dangerous/destructive commands (rm -rf, force-push, DROP TABLE, etc.)
# Event: PreToolUse | Matcher: Bash | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Only care about Bash tool
tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Check if command safety is enabled
enabled="$(config_get "guardrails.command_safety.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# ─── rm -rf patterns (6 variants) ──────────────────────────────────────────
# Matches: rm -rf, rm -fr, rm --recursive --force, rm -r -f, etc.
# On dangerous paths: /, ~, $HOME, .., *, .
RM_PATTERNS=(
  'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|--recursive\s+--force|--force\s+--recursive|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*)\s+(/|~|\$HOME|\.\.|[*]|\./?$)'
  'rm\s+-r\s+-f\s+(/|~|\$HOME|\.\.|[*]|\./?$)'
  'rm\s+-f\s+-r\s+(/|~|\$HOME|\.\.|[*]|\./?$)'
  'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|--recursive\s+--force)\s+\.'
)

for pattern in "${RM_PATTERNS[@]}"; do
  if echo "$command" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    deny "🛑 hapai: Destructive command blocked — 'rm -rf' on dangerous path. This could delete critical files."
  fi
done

# ─── Git destructive operations ─────────────────────────────────────────────
GIT_DESTRUCTIVE_PATTERNS=(
  'git\s+push\s+(-f|--force|--force-with-lease)'
  'git\s+push\s+[a-zA-Z_-]+\s+(-f|--force)'
  'git\s+reset\s+--hard'
  'git\s+clean\s+(-[a-zA-Z]*f|--force)'
  'git\s+checkout\s+--\s+\.'
  'git\s+restore\s+--source.*--worktree\s+\.'
)

for pattern in "${GIT_DESTRUCTIVE_PATTERNS[@]}"; do
  if echo "$command" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    deny "🛑 hapai: Destructive git command blocked — '$(echo "$command" | head -c 80)'. Use safer alternatives."
  fi
done

# ─── SQL destructive operations ─────────────────────────────────────────────
SQL_PATTERNS=(
  'DROP\s+(TABLE|DATABASE|SCHEMA|INDEX)'
  'TRUNCATE\s+(TABLE)?'
  'DELETE\s+FROM\s+\S+\s*;?\s*$'
)

command_upper="$(echo "$command" | tr '[:lower:]' '[:upper:]')"
for pattern in "${SQL_PATTERNS[@]}"; do
  if echo "$command_upper" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    deny "🛑 hapai: Destructive SQL command blocked — detected DROP/TRUNCATE/mass DELETE."
  fi
done

# ─── System destructive operations ──────────────────────────────────────────
SYSTEM_PATTERNS=(
  'chmod\s+(-R\s+)?777'
  'chmod\s+777\s+-R'
  '>\s*/dev/sd[a-z]'
  'mkfs\.'
  'dd\s+if=.*of=/dev/'
  ':(){.*};:'
)

for pattern in "${SYSTEM_PATTERNS[@]}"; do
  if echo "$command" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    deny "🛑 hapai: Destructive system command blocked — '$(echo "$command" | head -c 80)'."
  fi
done

allow
