#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-destructive.sh
# Blocks dangerous/destructive commands (rm -rf, force-push, DROP TABLE, etc.)
# Allows --force-with-lease (safe alternative to --force).
# Also blocks hapai kill/uninstall (self-protection).
# Event: PreToolUse | Matcher: Bash | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Check if command safety is enabled
enabled="$(config_get "guardrails.command_safety.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# Normalize: strip leading backslash, 'command', 'env', full paths to common binaries
# This prevents bypasses like \rm, command rm, /bin/rm, env rm
normalized="$(echo "$command" | sed -E 's/(^|[;&|]\s*)\\//g; s/(^|[;&|]\s*)(command|env|sudo)\s+/\1/g; s|/usr/(local/)?s?bin/||g; s|/bin/||g; s|/opt/homebrew/bin/||g')"

# ─── Self-protection: block hapai kill/uninstall ────────────────────────────
if echo "$normalized" | grep -qE '(^|[;&|])\s*hapai\s+(kill|uninstall)\b'; then
  state_increment "guard-destructive.deny_count"
  deny "hapai: Self-protection — 'hapai kill/uninstall' blocked. Run it manually outside Claude Code if needed."
fi

# ─── rm -rf patterns (normalized, catches \rm, command rm, /bin/rm) ─────────
RM_PATTERNS=(
  'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*|--recursive\s+--force|--force\s+--recursive|-r\s+-f|-f\s+-r)\s+(/|~|\$HOME|\.\.|[*]|\./?$)'
  'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*|--recursive\s+--force)\s+\.'
)

for pattern in "${RM_PATTERNS[@]}"; do
  if echo "$normalized" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    deny "hapai: Destructive command blocked — 'rm -rf' on dangerous path. This could delete critical files."
  fi
done

# ─── Git destructive operations (allows --force-with-lease as safe alternative) ─
GIT_DESTRUCTIVE_PATTERNS=(
  'git\s+push\s+.*(-f\b|--force\b)(?!.*-with-lease)'
  'git\s+push\s+.*--force\s'
  'git\s+reset\s+--hard'
  'git\s+clean\s+(-[a-zA-Z]*f|--force)'
  'git\s+checkout\s+--\s+\.'
  'git\s+restore\s+--source.*--worktree\s+\.'
)

# Check force-push specifically (allow --force-with-lease, block --force and -f)
if echo "$normalized" | grep -qE 'git\s+push\s' 2>/dev/null; then
  # Has force-with-lease? That's safe — allow it
  if echo "$normalized" | grep -qE '\-\-force-with-lease' 2>/dev/null; then
    : # safe, skip
  elif echo "$normalized" | grep -qE '(\s-f\b|\s--force\b)' 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    deny "hapai: Destructive git command blocked — force-push detected. Use --force-with-lease for a safer alternative."
  fi
fi

# Check other git destructive commands
OTHER_GIT_PATTERNS=(
  'git\s+reset\s+--hard'
  'git\s+clean\s+(-[a-zA-Z]*f|--force)'
  'git\s+checkout\s+--\s+\.'
  'git\s+restore\s+--source.*--worktree\s+\.'
)

for pattern in "${OTHER_GIT_PATTERNS[@]}"; do
  if echo "$normalized" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    deny "hapai: Destructive git command blocked — '$(echo "$command" | head -c 80)'. Use safer alternatives."
  fi
done

# ─── SQL destructive operations ─────────────────────────────────────────────
SQL_PATTERNS=(
  'DROP\s+(TABLE|DATABASE|SCHEMA|INDEX)'
  'TRUNCATE\s+'
)

command_upper="$(echo "$normalized" | tr '[:lower:]' '[:upper:]')"
for pattern in "${SQL_PATTERNS[@]}"; do
  if echo "$command_upper" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    deny "hapai: Destructive SQL command blocked — detected DROP/TRUNCATE."
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
  if echo "$normalized" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    deny "hapai: Destructive system command blocked — '$(echo "$command" | head -c 80)'."
  fi
done

allow
