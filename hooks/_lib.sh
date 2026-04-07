#!/usr/bin/env bash
# hapai/_lib.sh — Shared utilities for all hooks
# Sourced by every hook script. Provides JSON I/O, config loading, audit logging.
#
# Principles:
#   - Graceful failure: never crash the host tool (exit 0 on internal errors)
#   - Fast: all operations must complete within timeout budgets
#   - No external deps beyond jq (required) and standard unix tools

set -euo pipefail

# ─── Constants ──────────────────────────────────────────────────────────────
HAPAI_VERSION="1.0.0"
HAPAI_HOME="${HAPAI_HOME:-$HOME/.hapai}"
HAPAI_AUDIT_LOG="${HAPAI_HOME}/audit.jsonl"
HAPAI_STATE_DIR="${HAPAI_HOME}/state"

# ─── Ensure directories exist ──────────────────────────────────────────────
mkdir -p "$HAPAI_HOME" "$HAPAI_STATE_DIR" 2>/dev/null || true

# ─── Input/Output ───────────────────────────────────────────────────────────

# Read stdin JSON into global variable. Call once per hook.
_HAPAI_INPUT=""
read_input() {
  _HAPAI_INPUT="$(cat)"
}

# Extract a field from the input JSON
# Usage: get_field ".tool_input.command"
get_field() {
  local field="$1"
  echo "$_HAPAI_INPUT" | jq -r "$field // empty" 2>/dev/null || echo ""
}

# Get the tool name from input
get_tool_name() {
  get_field ".tool_name"
}

# Get the hook event name
get_hook_event() {
  get_field ".hook_event_name"
}

# ─── Response helpers ───────────────────────────────────────────────────────

# Deny the tool call with a reason message
# Uses exit code 2 + stderr (official Claude Code mechanism for blocking)
# Usage: deny "Cannot commit to main branch"
deny() {
  local reason="${1:-Blocked by hapai guardrail}"
  audit_log "deny" "$reason"
  echo "$reason" >&2
  exit 2
}

# Allow with an optional system message (informational, non-blocking)
# Uses hookSpecificOutput.additionalContext for inline warnings
# Usage: warn "This commit touches 15 files across 3 packages"
warn() {
  local message="${1:-}"
  if [[ -n "$message" ]]; then
    local hook_event
    hook_event="$(get_hook_event 2>/dev/null || echo "PreToolUse")"
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "$hook_event",
    "permissionDecision": "allow",
    "additionalContext": "$message"
  }
}
EOF
    audit_log "warn" "$message"
  fi
  exit 0
}

# Allow silently (hook has nothing to say)
allow() {
  audit_log "allow" ""
  exit 0
}

# ─── Configuration ──────────────────────────────────────────────────────────

# Find hapai.yaml: project-local first, then global
_HAPAI_CONFIG=""
find_config() {
  local project_config=""
  # Try project-local config
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    project_config="${CLAUDE_PROJECT_DIR}/hapai.yaml"
  else
    project_config="$(pwd)/hapai.yaml"
  fi

  if [[ -f "$project_config" ]]; then
    _HAPAI_CONFIG="$project_config"
  elif [[ -f "${HAPAI_HOME}/hapai.yaml" ]]; then
    _HAPAI_CONFIG="${HAPAI_HOME}/hapai.yaml"
  elif [[ -f "${HAPAI_HOME}/hapai.defaults.yaml" ]]; then
    _HAPAI_CONFIG="${HAPAI_HOME}/hapai.defaults.yaml"
  fi
}

# Read a config value from hapai.yaml using grep/awk (no yq dependency)
# Supports simple key: value and nested keys via dot notation (1 level)
# Usage: config_get "guardrails.branch_protection.enabled" "true"
config_get() {
  local key="$1"
  local default="${2:-}"

  if [[ -z "$_HAPAI_CONFIG" ]]; then
    find_config
  fi

  if [[ -z "$_HAPAI_CONFIG" ]] || [[ ! -f "$_HAPAI_CONFIG" ]]; then
    echo "$default"
    return
  fi

  # Simple approach: search for the key as-is or last segment after dot
  local value=""
  local leaf_key="${key##*.}"

  # Try exact key match (indentation-aware)
  value=$(grep -E "^\s*${leaf_key}\s*:" "$_HAPAI_CONFIG" 2>/dev/null | head -1 | sed 's/^[^:]*:\s*//' | sed 's/\s*#.*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/" | tr -d '[:space:]' || echo "")

  if [[ -n "$value" && "$value" != "[]" && "$value" != "{}" ]]; then
    echo "$value"
  else
    echo "$default"
  fi
}

# Read a YAML list into a bash array (one item per line)
# Usage: config_get_list "guardrails.branch_protection.protected"
config_get_list() {
  local key="$1"
  local leaf_key="${key##*.}"

  if [[ -z "$_HAPAI_CONFIG" ]]; then
    find_config
  fi

  if [[ -z "$_HAPAI_CONFIG" ]] || [[ ! -f "$_HAPAI_CONFIG" ]]; then
    return
  fi

  # Handle inline array: key: [val1, val2, val3]
  local inline
  inline=$(grep -E "^\s*${leaf_key}\s*:" "$_HAPAI_CONFIG" 2>/dev/null | head -1 | sed 's/^[^:]*:\s*//' | tr -d '[:space:]' || echo "")

  if [[ "$inline" == "["*"]" ]]; then
    # Strip brackets, split by comma, strip quotes
    echo "$inline" | tr -d '[]"'"'" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
    return
  fi

  # Handle block list:
  #   key:
  #     - val1
  #     - val2
  local in_section=0
  while IFS= read -r line; do
    if [[ $in_section -eq 1 ]]; then
      if echo "$line" | grep -qE '^\s+-\s+'; then
        echo "$line" | sed 's/^\s*-\s*//' | sed 's/\s*#.*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/"
      else
        break
      fi
    fi
    if echo "$line" | grep -qE "^\s*${leaf_key}\s*:"; then
      in_section=1
    fi
  done < "$_HAPAI_CONFIG"
}

# ─── Audit Log ──────────────────────────────────────────────────────────────

# Log an event to the audit JSONL file
# Usage: audit_log "deny" "Blocked commit to main"
audit_log() {
  local result="${1:-unknown}"
  local reason="${2:-}"
  local tool_name
  tool_name="$(get_tool_name 2>/dev/null || echo "unknown")"
  local hook_event
  hook_event="$(get_hook_event 2>/dev/null || echo "unknown")"
  local hook_name
  hook_name="$(basename "${BASH_SOURCE[1]:-unknown}" .sh 2>/dev/null || echo "unknown")"
  local project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")"

  # Escape reason for JSON
  local escaped_reason
  escaped_reason="$(echo "$reason" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ' | head -c 500)"

  # Append to audit log (non-blocking, fire-and-forget)
  {
    printf '{"ts":"%s","event":"%s","hook":"%s","tool":"%s","result":"%s","reason":"%s","project":"%s"}\n' \
      "$timestamp" "$hook_event" "$hook_name" "$tool_name" "$result" "$escaped_reason" "$project_dir"
  } >> "$HAPAI_AUDIT_LOG" 2>/dev/null || true
}

# ─── State Management ───────────────────────────────────────────────────────

# Read a state value
# Usage: state_get "guard-branch.deny_count" "0"
state_get() {
  local key="$1"
  local default="${2:-}"
  local state_file="${HAPAI_STATE_DIR}/${key}"

  if [[ -f "$state_file" ]]; then
    cat "$state_file" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# Write a state value
# Usage: state_set "guard-branch.deny_count" "5"
state_set() {
  local key="$1"
  local value="$2"
  local state_file="${HAPAI_STATE_DIR}/${key}"

  echo "$value" > "$state_file" 2>/dev/null || true
}

# Increment a state counter
# Usage: state_increment "guard-branch.deny_count"
state_increment() {
  local key="$1"
  local current
  current="$(state_get "$key" "0")"
  local next=$((current + 1))
  state_set "$key" "$next"
  echo "$next"
}

# ─── Git Helpers ────────────────────────────────────────────────────────────

# Get current git branch name
git_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
}

# Check if current branch is in a protected list
# Usage: is_protected_branch "main"
is_protected_branch() {
  local branch="$1"
  local protected
  protected="$(config_get_list "guardrails.branch_protection.protected")"

  if [[ -z "$protected" ]]; then
    # Default protected branches
    protected="main
master"
  fi

  echo "$protected" | grep -qx "$branch" 2>/dev/null
}

# ─── Error handling ─────────────────────────────────────────────────────────

# Trap: on any unexpected error, allow gracefully (never break the host tool)
_hapai_error_handler() {
  # Log the error but don't block
  audit_log "error" "Internal hook error at line ${BASH_LINENO[0]:-unknown}"
  exit 0
}

trap '_hapai_error_handler' ERR
