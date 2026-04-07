#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-commit-msg.sh
# Blocks commits containing Co-Authored-By, AI mentions, or other blocked patterns.
# Only scans the commit message portion, not the entire command (avoids false positives
# on legitimate package names like "anthropic-client").
# Event: PreToolUse | Matcher: Bash | if: Bash(git commit*) | Timeout: 7s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

tool_name="$(get_tool_name)"
[[ "$tool_name" != "Bash" ]] && exit 0

command="$(get_field '.tool_input.command')"
[[ -z "$command" ]] && exit 0

# Only check git commit commands (not push, log, etc.)
echo "$command" | grep -qE '(^|;|\||&&)\s*git\s+commit\b' || exit 0

# Check if commit hygiene is enabled
enabled="$(config_get "guardrails.commit_hygiene.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# Extract the commit message from the command (not the whole command string)
# Handles: -m "message", -m 'message', heredoc $(cat <<'EOF' ... EOF)
commit_msg=""

# Try -m "..." or -m '...' (greedy match for the message content)
if echo "$command" | grep -qE '\-m\s+'; then
  # Extract everything after -m (the message argument)
  commit_msg="$(echo "$command" | sed -n "s/.*-m\s*[\"']\(.*\)/\1/p" | head -1)"
fi

# If heredoc pattern, extract the body
if echo "$command" | grep -qE 'cat\s+<<'; then
  commit_msg="$(echo "$command" | sed -n '/cat.*<<.*EOF/,/EOF/p' | grep -v 'EOF' | grep -v 'cat')"
fi

# Fallback: if no message extracted, scan the full command (less precise)
if [[ -z "$commit_msg" ]]; then
  commit_msg="$command"
fi

# Default blocked patterns (case-insensitive)
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
)

commit_msg_lower="$(echo "$commit_msg" | tr '[:upper:]' '[:lower:]')"

for pattern in "${DEFAULT_PATTERNS[@]}"; do
  pattern_lower="$(echo "$pattern" | tr '[:upper:]' '[:lower:]')"
  if echo "$commit_msg_lower" | grep -qi "$pattern_lower" 2>/dev/null; then
    state_increment "guard-commit-msg.deny_count"
    deny "hapai: Commit blocked — contains forbidden pattern '$pattern'. Remove AI attribution from the commit message."
  fi
done

# Also check config-defined patterns
while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  pattern_lower="$(echo "$pattern" | tr '[:upper:]' '[:lower:]')"
  if echo "$commit_msg_lower" | grep -qi "$pattern_lower" 2>/dev/null; then
    state_increment "guard-commit-msg.deny_count"
    deny "hapai: Commit blocked — contains forbidden pattern '$pattern'. Remove it from the commit message."
  fi
done <<< "$(config_get_list "guardrails.commit_hygiene.blocked_patterns")"

allow
