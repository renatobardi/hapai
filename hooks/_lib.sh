#!/usr/bin/env bash
# hapai/_lib.sh — Shared utilities for all hooks
# Sourced by every hook script. Provides JSON I/O, config loading, audit logging.
#
# Principles:
#   - Deterministic blocking: deny() uses exit 2 + stderr (Claude Code official API)
#   - Graceful failure: internal errors exit 0 (never crash the host tool)
#   - Fast: all operations must complete within timeout budgets (PreToolUse=7s, PostToolUse=5s)
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

# Deny the tool call with a reason message.
# Uses exit code 2 + stderr (official Claude Code blocking mechanism).
# Usage: deny "Cannot commit to main branch"
deny() {
  local reason="${1:-Blocked by hapai guardrail}"
  audit_log "deny" "$reason"
  echo "$reason" >&2
  exit 2
}

# Allow with an optional warning message (informational, non-blocking).
# Uses jq for safe JSON construction (no injection risk).
# Usage: warn "This commit touches 15 files across 3 packages"
warn() {
  local message="${1:-}"
  if [[ -n "$message" ]]; then
    local hook_event
    hook_event="$(get_hook_event 2>/dev/null || echo "PreToolUse")"
    # Safe JSON construction via jq --arg (handles quotes, newlines, special chars)
    jq -n \
      --arg event "$hook_event" \
      --arg ctx "$message" \
      '{hookSpecificOutput: {hookEventName: $event, permissionDecision: "allow", additionalContext: $ctx}}'
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
_HAPAI_CONFIG="${_HAPAI_CONFIG:-}"
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

# YAML indent tracking helpers (used by config_get and config_get_list)
_get_indent_at() { eval "echo \$indent_at_$1"; }
_set_indent_at() { eval "indent_at_$1=$2"; }

# Read a config value from hapai.yaml — context-aware YAML parser.
# Walks the dot-separated key path through YAML indentation levels.
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

  # Split key into path segments
  IFS='.' read -ra segments <<< "$key"
  local depth=${#segments[@]}
  local leaf_key="${segments[$((depth - 1))]}"

  # Walk the YAML file tracking indentation context
  local match_depth=0
  # indent_at[N] = the indentation level where depth N was matched
  local indent_at_0=-1 indent_at_1=-1 indent_at_2=-1 indent_at_3=-1 indent_at_4=-1

  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Calculate indentation (number of leading spaces)
    local stripped="${line#"${line%%[![:space:]]*}"}"
    # Count leading spaces: remove from the beginning until first non-space
    local indent=0
    while [[ ${#stripped} -lt ${#line} && "${line:$indent:1}" == " " ]]; do
      indent=$((indent + 1))
    done

    # Extract key from this line
    local line_key=""
    if [[ "$stripped" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*)[[:space:]]*: ]]; then
      line_key="${BASH_REMATCH[1]}"
    fi

    [[ -z "$line_key" ]] && continue

    # If we've gone back to a shallower indentation, reset match_depth
    if [[ $match_depth -gt 0 ]]; then
      local parent_indent
      parent_indent="$(_get_indent_at $match_depth)"
      if [[ $indent -le $parent_indent ]]; then
        # Recalculate: find the deepest level whose indent is strictly less than current
        match_depth=0
        local i
        for ((i=1; i<=4; i++)); do
          local lvl_indent
          lvl_indent="$(_get_indent_at $i)"
          if [[ $lvl_indent -ge 0 ]] && [[ $indent -gt $lvl_indent ]]; then
            match_depth=$i
          else
            break
          fi
        done
      fi
    fi

    # Check if this line matches the expected key at the current depth
    local expected_key="${segments[$match_depth]:-}"
    if [[ "$line_key" == "$expected_key" ]]; then
      if [[ $match_depth -eq $((depth - 1)) ]]; then
        # Found the leaf key in the correct context!
        local value
        # Extract value: remove "key: " prefix, strip trailing comments, unquote
        value="$(echo "$stripped" | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//')"
        # Remove surrounding quotes (either single or double)
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
          value="${BASH_REMATCH[1]}"
        elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
          value="${BASH_REMATCH[1]}"
        fi
        # Trim trailing whitespace only (don't strip all spaces)
        value="${value%"${value##*[^[:space:]]}"}"
        if [[ -n "$value" && "$value" != "[]" && "$value" != "{}" ]]; then
          echo "$value"
          return
        fi
        echo "$default"
        return
      else
        # Matched an intermediate key — go deeper
        match_depth=$((match_depth + 1))
        _set_indent_at $match_depth $indent
      fi
    fi
  done < "$_HAPAI_CONFIG"

  echo "$default"
}

# Read a YAML list — context-aware (respects section hierarchy).
# Usage: config_get_list "guardrails.branch_protection.protected"
config_get_list() {
  local key="$1"

  if [[ -z "$_HAPAI_CONFIG" ]]; then
    find_config
  fi

  if [[ -z "$_HAPAI_CONFIG" ]] || [[ ! -f "$_HAPAI_CONFIG" ]]; then
    return
  fi

  # Split key into path segments
  IFS='.' read -ra segments <<< "$key"
  local depth=${#segments[@]}

  local match_depth=0
  local indent_at_0=-1 indent_at_1=-1 indent_at_2=-1 indent_at_3=-1 indent_at_4=-1
  local in_target=0
  local target_indent=-1

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    local stripped="${line#"${line%%[![:space:]]*}"}"
    # Count leading spaces: remove from the beginning until first non-space
    local indent=0
    while [[ ${#stripped} -lt ${#line} && "${line:$indent:1}" == " " ]]; do
      indent=$((indent + 1))
    done

    # If we're reading list items from the target key
    if [[ $in_target -eq 1 ]]; then
      if [[ $indent -le $target_indent ]]; then
        return
      fi
      if [[ "$stripped" =~ ^-[[:space:]] ]]; then
        local item_value="${stripped#-[[:space:]]}"
        # Remove trailing comments
        item_value="${item_value%% #*}"
        # Unquote
        if [[ "$item_value" =~ ^\"(.*)\"$ ]]; then
          item_value="${BASH_REMATCH[1]}"
        elif [[ "$item_value" =~ ^\'(.*)\'$ ]]; then
          item_value="${BASH_REMATCH[1]}"
        fi
        echo "$item_value"
      fi
      continue
    fi

    # Extract key from this line
    local line_key=""
    if [[ "$stripped" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*)[[:space:]]*: ]]; then
      line_key="${BASH_REMATCH[1]}"
    fi
    [[ -z "$line_key" ]] && continue

    # Track depth via indentation (same approach as config_get)
    if [[ $match_depth -gt 0 ]]; then
      local parent_indent
      parent_indent="$(_get_indent_at $match_depth)"
      if [[ $indent -le $parent_indent ]]; then
        match_depth=0
        local i
        for ((i=1; i<=4; i++)); do
          local lvl_indent
          lvl_indent="$(_get_indent_at $i)"
          if [[ $lvl_indent -ge 0 ]] && [[ $indent -gt $lvl_indent ]]; then
            match_depth=$i
          else
            break
          fi
        done
      fi
    fi

    local expected_key="${segments[$match_depth]:-}"
    if [[ "$line_key" == "$expected_key" ]]; then
      if [[ $match_depth -eq $((depth - 1)) ]]; then
        # Found the leaf key — check for inline array or block list
        local value_part
        value_part="$(echo "$stripped" | sed 's/^[^:]*:[[:space:]]*//' | tr -d '[:space:]')"

        if [[ "$value_part" == "["*"]" ]]; then
          echo "$value_part" | tr -d '[]"'"'" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
          return
        fi

        # Block list follows on subsequent lines
        in_target=1
        target_indent=$indent
      else
        match_depth=$((match_depth + 1))
        _set_indent_at $match_depth $indent
      fi
    fi
  done < "$_HAPAI_CONFIG"
}

# ─── Audit Log ──────────────────────────────────────────────────────────────

# Log an event to the audit JSONL file — safe JSON via jq.
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

  # Safe JSON construction via jq (handles all special chars, tabs, control chars)
  {
    jq -n -c \
      --arg ts "$timestamp" \
      --arg event "$hook_event" \
      --arg hook "$hook_name" \
      --arg tool "$tool_name" \
      --arg result "$result" \
      --arg reason "$(echo "$reason" | head -c 500)" \
      --arg project "$project_dir" \
      '{ts: $ts, event: $event, hook: $hook, tool: $tool, result: $result, reason: $reason, project: $project}'
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

# Trap: on any unexpected error, allow gracefully (never block on internal bugs)
_hapai_error_handler() {
  # Log the error but don't block — fail-open on internal errors only
  audit_log "error" "Internal hook error at line ${BASH_LINENO[0]:-unknown}"
  exit 0
}

trap '_hapai_error_handler' ERR
