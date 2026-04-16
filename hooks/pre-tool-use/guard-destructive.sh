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
  ctx="$(_build_context \
    "risk_category=self_protection" \
    "matched_pattern=hapai_kill_uninstall" \
    "command_preview=$(echo "$command" | head -c 120)")"
  deny "hapai: Self-protection — 'hapai kill/uninstall' blocked. Run it manually outside Claude Code if needed." "$ctx"
fi

# ─── rm -rf patterns (normalized, catches \rm, command rm, /bin/rm) ─────────
RM_PATTERNS=(
  'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*|--recursive\s+--force|--force\s+--recursive|-r\s+-f|-f\s+-r)\s+(/|~|\$HOME|\.\.|[*]|\./?$)'
  'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*|--recursive\s+--force)\s+\.'
)

for pattern in "${RM_PATTERNS[@]}"; do
  if echo "$normalized" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    ctx="$(_build_context \
      "risk_category=filesystem" \
      "matched_pattern=rm_rf_dangerous_path" \
      "command_preview=$(echo "$command" | head -c 120)")"
    deny "hapai: Destructive command blocked — 'rm -rf' on dangerous path. This could delete critical files." "$ctx"
  fi
done

# ─── Git destructive operations (allows --force-with-lease as safe alternative) ─
# Check force-push specifically (allow --force-with-lease, block --force and -f)
if echo "$normalized" | grep -qE 'git\s+push\s' 2>/dev/null; then
  # Has force-with-lease? That's safe — allow it
  if echo "$normalized" | grep -qE '\-\-force-with-lease' 2>/dev/null; then
    : # safe, skip
  elif echo "$normalized" | grep -qE '(\s-f\b|\s--force\b)' 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    ctx="$(_build_context \
      "risk_category=git" \
      "matched_pattern=force_push" \
      "command_preview=$(echo "$command" | head -c 120)")"
    deny "hapai: Destructive git command blocked — force-push detected. Use --force-with-lease for a safer alternative." "$ctx"
  fi
fi

# Check other git destructive commands
OTHER_GIT_PATTERNS=(
  'git\s+reset\s+--hard'
  'git\s+clean\s+(-[a-zA-Z]*f|--force)'
  'git\s+checkout\s+--\s+\.'
  'git\s+restore\s+--source.*--worktree\s+\.'
)

GIT_PATTERN_NAMES=(
  "git_reset_hard"
  "git_clean_force"
  "git_checkout_discard"
  "git_restore_worktree"
)

for i in "${!OTHER_GIT_PATTERNS[@]}"; do
  pattern="${OTHER_GIT_PATTERNS[$i]}"
  pattern_name="${GIT_PATTERN_NAMES[$i]}"
  if echo "$normalized" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    ctx="$(_build_context \
      "risk_category=git" \
      "matched_pattern=$pattern_name" \
      "command_preview=$(echo "$command" | head -c 120)")"
    deny "hapai: Destructive git command blocked — '$(echo "$command" | head -c 80)'. Use safer alternatives." "$ctx"
  fi
done

# ─── SQL destructive operations ─────────────────────────────────────────────
SQL_PATTERNS=(
  'DROP\s+(TABLE|DATABASE|SCHEMA|INDEX)'
  'TRUNCATE\s+'
)

SQL_PATTERN_NAMES=(
  "sql_drop"
  "sql_truncate"
)

command_upper="$(echo "$normalized" | tr '[:lower:]' '[:upper:]')"
for i in "${!SQL_PATTERNS[@]}"; do
  pattern="${SQL_PATTERNS[$i]}"
  pattern_name="${SQL_PATTERN_NAMES[$i]}"
  if echo "$command_upper" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    ctx="$(_build_context \
      "risk_category=database" \
      "matched_pattern=$pattern_name" \
      "command_preview=$(echo "$command" | head -c 120)")"
    deny "hapai: Destructive SQL command blocked — detected DROP/TRUNCATE." "$ctx"
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

SYSTEM_PATTERN_NAMES=(
  "chmod_777"
  "chmod_777_recursive"
  "write_block_device"
  "mkfs"
  "dd_device"
  "fork_bomb"
)

for i in "${!SYSTEM_PATTERNS[@]}"; do
  pattern="${SYSTEM_PATTERNS[$i]}"
  pattern_name="${SYSTEM_PATTERN_NAMES[$i]}"
  if echo "$normalized" | grep -qE "$pattern" 2>/dev/null; then
    state_increment "guard-destructive.deny_count"
    ctx="$(_build_context \
      "risk_category=system" \
      "matched_pattern=$pattern_name" \
      "command_preview=$(echo "$command" | head -c 120)")"
    deny "hapai: Destructive system command blocked — '$(echo "$command" | head -c 80)'." "$ctx"
  fi
done

allow
