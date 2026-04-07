#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-commit-msg.sh
# Blocks commits containing Co-Authored-By, AI mentions, or other blocked patterns
# Event: PreToolUse | Matcher: Bash | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Only care about Bash tool
tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Only check git commit commands
echo "$command" | grep -qE 'git\s+commit' || exit 0

# Check if commit hygiene is enabled
enabled="$(config_get "guardrails.commit_hygiene.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# Get blocked patterns from config, with defaults
DEFAULT_PATTERNS=(
  "Co-Authored-By:"
  "co-authored-by:"
  "Generated with Claude"
  "Generated with.*Claude"
  "noreply@anthropic.com"
  "Claude Code"
  "Claude Opus"
  "Claude Sonnet"
  "Claude Haiku"
  "Anthropic"
)

# Check each default pattern against the command
# (covers -m "message" and heredoc patterns)
command_lower="$(echo "$command" | tr '[:upper:]' '[:lower:]')"

for pattern in "${DEFAULT_PATTERNS[@]}"; do
  pattern_lower="$(echo "$pattern" | tr '[:upper:]' '[:lower:]')"
  if echo "$command_lower" | grep -qi "$pattern_lower" 2>/dev/null; then
    state_increment "guard-commit-msg.deny_count"
    deny "🛑 hapai: Commit blocked — contains forbidden pattern '$pattern'. Remove AI attribution from the commit message."
  fi
done

# Also check config-defined patterns
while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  pattern_lower="$(echo "$pattern" | tr '[:upper:]' '[:lower:]')"
  if echo "$command_lower" | grep -qi "$pattern_lower" 2>/dev/null; then
    state_increment "guard-commit-msg.deny_count"
    deny "🛑 hapai: Commit blocked — contains forbidden pattern '$pattern'. Remove it from the commit message."
  fi
done <<< "$(config_get_list "guardrails.commit_hygiene.blocked_patterns")"

allow
