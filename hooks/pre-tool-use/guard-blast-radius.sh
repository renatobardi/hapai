#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/guard-blast-radius.sh
# Warns or blocks when a commit touches too many files or packages (monorepo awareness).
# Behavior depends on fail_open config: true=warn, false=block.
# Event: PreToolUse | Matcher: Bash | if: Bash(git commit*) | Timeout: 7s

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

# Check if enabled
enabled="$(config_get "guardrails.blast_radius.enabled" "true")"
[[ "$enabled" != "true" ]] && allow

# Check if we're in a git repo
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# Count staged files (trim whitespace from line count)
staged_files="$(git diff --cached --name-only 2>/dev/null)"
file_count="$(echo "$staged_files" | grep -c '.' 2>/dev/null | tr -d ' ' || echo "0")"

# Get thresholds from config
max_files="$(config_get "guardrails.blast_radius.max_files" "10")"
max_packages="$(config_get "guardrails.blast_radius.max_packages" "2")"
fail_open="$(config_get "guardrails.blast_radius.fail_open" "true")"

# Cooldown: if repeated warnings occurred, escalate to fail_closed temporarily
if cooldown_active "guard-blast-radius" 2>/dev/null; then
  fail_open="false"
fi

warnings=""

# Check file count
if [[ "$file_count" -gt "$max_files" ]]; then
  warnings="⚠️ Blast radius: $file_count files staged (threshold: $max_files)."
fi

# Check package/directory spread (monorepo awareness)
# Count unique top-level directories (packages/, apps/, etc.)
if [[ -n "$staged_files" ]]; then
  package_dirs="$(echo "$staged_files" | grep -oE '^(packages|apps|modules|services)/[^/]+' 2>/dev/null | sort -u)"

  if [[ -n "$package_dirs" ]]; then
    package_count="$(echo "$package_dirs" | wc -l | tr -d ' ')"

    if [[ "$package_count" -gt "$max_packages" ]]; then
      package_list="$(echo "$package_dirs" | tr '\n' ', ' | sed 's/,$//')"
      if [[ -n "$warnings" ]]; then
        warnings="$warnings Also touches $package_count packages ($package_list)."
      else
        warnings="⚠️ Blast radius: commit touches $package_count packages ($package_list) (threshold: $max_packages)."
      fi
    fi
  fi
fi

# If warnings exist, act on them
if [[ -n "$warnings" ]]; then
  state_increment "guard-blast-radius.warn_count"
  cooldown_record "guard-blast-radius" 2>/dev/null || true

  if [[ "$fail_open" == "true" ]]; then
    warn "$warnings Consider splitting into smaller, focused commits."
  else
    deny "🛑 hapai: $warnings Split into smaller commits before proceeding."
  fi
fi

allow
