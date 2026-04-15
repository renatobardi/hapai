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
# IMPORTANT: mkdir guards (|| true) are REQUIRED because the ERR trap is not yet installed.
# If mkdir fails without || true, and ERR trap isn't set, bash would exit non-zero
# but the trap (which exits 0 on error to fail-open) wouldn't fire yet.
# The ERR trap is installed at the end of this file (see below).
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

# YAML indent tracking helpers (sanitized to prevent eval injection)
# Only accept numeric indices to prevent code injection
_get_indent_at() {
  local idx="$1"
  # Validate idx is numeric only — prevent eval injection
  [[ ! "$idx" =~ ^[0-9]+$ ]] && echo "-1" && return
  eval "echo \$indent_at_$idx"
}
_set_indent_at() {
  local idx="$1" val="$2"
  # Validate idx and val are safe — prevent eval injection
  [[ ! "$idx" =~ ^[0-9]+$ ]] && return
  [[ ! "$val" =~ ^-?[0-9]+$ ]] && return
  eval "indent_at_$idx=$val"
}

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
  # Pass reason directly to jq --arg to handle escaping (jq will limit length internally)
  {
    jq -n -c \
      --arg ts "$timestamp" \
      --arg event "$hook_event" \
      --arg hook "$hook_name" \
      --arg tool "$tool_name" \
      --arg result "$result" \
      --arg reason "${reason:0:500}" \
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

# ─── Flow Engine ────────────────────────────────────────────────────────────

# Parse flow steps from YAML — returns JSON objects (one per line)
# Handles YAML sequences of mappings under flows.<name>.steps
# Usage: config_get_flow_steps "pre_commit_review"
config_get_flow_steps() {
  local flow_name="$1"

  if [[ -z "$_HAPAI_CONFIG" ]]; then
    find_config
  fi

  [[ -z "$_HAPAI_CONFIG" || ! -f "$_HAPAI_CONFIG" ]] && return

  local segments=(flows "$flow_name" steps)
  local depth=3
  local match_depth=0
  local indent_at_0=-1 indent_at_1=-1 indent_at_2=-1 indent_at_3=-1 indent_at_4=-1
  local in_steps=0
  local step_indent=-1
  local current_hook=""
  local current_gate="block"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    local stripped="${line#"${line%%[![:space:]]*}"}"
    local indent=0
    while [[ ${#stripped} -lt ${#line} && "${line:$indent:1}" == " " ]]; do
      indent=$((indent + 1))
    done

    if [[ $in_steps -eq 1 ]]; then
      # Left the steps block — flush last step and stop
      if [[ $indent -le $step_indent && "$stripped" != -* ]]; then
        if [[ -n "$current_hook" ]]; then
          jq -cn --arg hook "$current_hook" --arg gate "$current_gate" \
            '{hook: $hook, gate: $gate}' 2>/dev/null || true
        fi
        break
      fi

      # New step: - hook: <name>
      if [[ "$stripped" =~ ^-[[:space:]]+hook:[[:space:]]+(.+)$ ]]; then
        if [[ -n "$current_hook" ]]; then
          jq -cn --arg hook "$current_hook" --arg gate "$current_gate" \
            '{hook: $hook, gate: $gate}' 2>/dev/null || true
        fi
        current_hook="${BASH_REMATCH[1]}"
        # Strip surrounding quotes (both double and single) and trailing spaces
        # First remove trailing spaces
        current_hook="${current_hook%"${current_hook##*[^[:space:]]}"}"
        # Then remove quotes: leading " ' and trailing " '
        current_hook="${current_hook#\"}" ; current_hook="${current_hook%\"}"
        current_hook="${current_hook#\'}" ; current_hook="${current_hook%\'}"
        current_gate="block"
        continue
      fi

      # gate: value (indented under the - hook: item)
      if [[ "$stripped" =~ ^gate:[[:space:]]+([a-z]+) ]]; then
        current_gate="${BASH_REMATCH[1]}"
        continue
      fi

      continue
    fi

    # Navigation: find flows.<name>.steps
    local line_key=""
    if [[ "$stripped" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*)[[:space:]]*: ]]; then
      line_key="${BASH_REMATCH[1]}"
    fi
    [[ -z "$line_key" ]] && continue

    if [[ $match_depth -gt 0 ]]; then
      local parent_indent
      parent_indent="$(_get_indent_at $match_depth)"
      if [[ $indent -le $parent_indent ]]; then
        match_depth=0
        local i
        for ((i=1; i<=4; i++)); do
          local lvl_indent
          lvl_indent="$(_get_indent_at $i)"
          if [[ $lvl_indent -ge 0 && $indent -gt $lvl_indent ]]; then
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
        in_steps=1
        step_indent=$indent
      else
        match_depth=$((match_depth + 1))
        _set_indent_at $match_depth $indent
      fi
    fi
  done < "$_HAPAI_CONFIG"

  # Flush last step (EOF inside steps block)
  if [[ -n "$current_hook" ]]; then
    jq -cn --arg hook "$current_hook" --arg gate "$current_gate" \
      '{hook: $hook, gate: $gate}' 2>/dev/null || true
  fi
}

# Flow execution globals — used by flow-dispatcher.sh
_FLOW_DENIED=0
_FLOW_WARNED=0
_FLOW_WARNINGS=""

# Execute one flow step with gate semantics.
# Sets _FLOW_DENIED=1 on hard denial (gate=block + hook exited 2).
# Sets _FLOW_WARNED=1 and appends to _FLOW_WARNINGS on warn/gate=warn.
# Always returns 0 (never triggers ERR trap on caller).
# Usage: flow_run_step "<hook_path>" "<gate: block|warn|skip>"
flow_run_step() {
  local hook_path="$1"
  local gate="${2:-block}"

  [[ ! -f "$hook_path" ]] && return 0

  local tmp_out tmp_err
  tmp_out="$(mktemp 2>/dev/null)" || tmp_out="/tmp/hapai_flow_out_$$"
  tmp_err="$(mktemp 2>/dev/null)" || tmp_err="/tmp/hapai_flow_err_$$"

  local exit_code=0
  echo "$_HAPAI_INPUT" | bash "$hook_path" >"$tmp_out" 2>"$tmp_err" || exit_code=$?

  local hook_out hook_err
  hook_out="$(cat "$tmp_out" 2>/dev/null)"
  hook_err="$(cat "$tmp_err" 2>/dev/null)"
  rm -f "$tmp_out" "$tmp_err" 2>/dev/null || true

  if [[ $exit_code -eq 2 ]]; then
    case "$gate" in
      block)
        echo "$hook_err" >&2
        _FLOW_DENIED=1
        ;;
      warn)
        _FLOW_WARNED=1
        [[ -n "$hook_err" ]] && _FLOW_WARNINGS="${_FLOW_WARNINGS}${hook_err} "
        ;;
    esac
  else
    # Hook allowed — collect any warnings it emitted
    if [[ -n "$hook_out" ]]; then
      local ctx
      ctx="$(echo "$hook_out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
      if [[ -n "$ctx" ]]; then
        _FLOW_WARNED=1
        _FLOW_WARNINGS="${_FLOW_WARNINGS}${ctx} "
      fi
    fi
  fi

  return 0
}

# ─── Advanced State: Blocklist ───────────────────────────────────────────────

_HAPAI_BLOCKLIST="${HAPAI_STATE_DIR}/blocklist.json"

# Parse duration string to seconds: "30m" → 1800, "2h" → 7200, "1d" → 86400
_parse_duration() {
  local spec="$1"
  # Strip non-alphanumeric trailing chars
  local num="${spec%[mhds]}"
  local unit="${spec: -1}"
  # Ensure num is a valid integer
  [[ ! "$num" =~ ^[0-9]+$ ]] && echo "1800" && return
  case "$unit" in
    m) echo $((num * 60)) ;;
    h) echo $((num * 3600)) ;;
    d) echo $((num * 86400)) ;;
    s) echo "$num" ;;
    *) echo $((num * 60)) ;; # assume minutes
  esac
}

# Compute ISO 8601 UTC timestamp N seconds in the future (cross-platform)
_timestamp_future() {
  local seconds="$1"
  local epoch_now epoch_then
  epoch_now="$(date -u +%s 2>/dev/null)" || epoch_now=0
  epoch_then=$((epoch_now + seconds))
  # Try GNU date (Linux), fall back to BSD date (macOS)
  if date -d "@${epoch_then}" &>/dev/null 2>&1; then
    date -u -d "@${epoch_then}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null
  else
    date -u -r "$epoch_then" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null
  fi
}

# Remove expired entries from blocklist.json
# Early-exit optimization: skip if blocklist is empty (no I/O in hot path)
blocklist_clean() {
  [[ ! -f "$_HAPAI_BLOCKLIST" ]] && return 0

  # Quick check: if blocklist is empty, skip processing (suppress output with >/dev/null)
  if jq -e 'length == 0' "$_HAPAI_BLOCKLIST" 2>/dev/null >/dev/null; then
    return 0
  fi

  local now_epoch
  now_epoch="$(date -u +%s 2>/dev/null)" || return 0

  local cleaned
  cleaned="$(jq -r --argjson now "$now_epoch" \
    '[.[] | select(
       (.expires_at | if . == "" then true
        else (strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) > $now
        end)
     )]' "$_HAPAI_BLOCKLIST" 2>/dev/null)" || return 0

  echo "$cleaned" > "$_HAPAI_BLOCKLIST" 2>/dev/null || true
}

# Add a pattern to the temporary blocklist.
# Usage: blocklist_add "main" "branch" "1800" "CI is broken"
blocklist_add() {
  local pattern="$1"
  local type="${2:-general}"
  local duration_seconds="${3:-1800}"
  local reason="${4:-}"

  local expires_at
  expires_at="$(_timestamp_future "$duration_seconds")"

  # Initialize file if needed
  if [[ ! -f "$_HAPAI_BLOCKLIST" ]]; then
    echo "[]" > "$_HAPAI_BLOCKLIST" 2>/dev/null || return 0
  fi

  # Remove any existing entry for same pattern+type, then append new
  local updated
  updated="$(jq -r \
    --arg pat "$pattern" --arg typ "$type" \
    --arg exp "$expires_at" --arg rsn "${reason:0:200}" \
    '[.[] | select(.pattern != $pat or .type != $typ)] +
     [{pattern: $pat, type: $typ, expires_at: $exp, reason: $rsn}]' \
    "$_HAPAI_BLOCKLIST" 2>/dev/null)" || return 0

  echo "$updated" > "$_HAPAI_BLOCKLIST" 2>/dev/null || true
}

# Check if a pattern is in the active blocklist.
# Returns 0 (shell true) if blocked, 1 if not blocked.
# Auto-removes expired entries.
# Usage: blocklist_check "main" "branch" && deny "branch is blocked"
blocklist_check() {
  local pattern="$1"
  local type="${2:-general}"

  [[ ! -f "$_HAPAI_BLOCKLIST" ]] && return 1

  blocklist_clean 2>/dev/null || true

  local is_blocked
  is_blocked="$(jq -r \
    --arg pat "$pattern" --arg typ "$type" \
    'any(.[]; .pattern == $pat and .type == $typ)' \
    "$_HAPAI_BLOCKLIST" 2>/dev/null)" || return 1

  [[ "$is_blocked" == "true" ]] && return 0 || return 1
}

# ─── Advanced State: Cooldown ────────────────────────────────────────────────

_HAPAI_COOLDOWN_DIR="${HAPAI_STATE_DIR}/cooldown"
mkdir -p "$_HAPAI_COOLDOWN_DIR" 2>/dev/null || true

# Check if a hook is in cooldown (aggressive mode).
# Returns 0 (shell true) if in cooldown, 1 if not.
# Usage: cooldown_active "guard-blast-radius" && fail_open="false"
cooldown_active() {
  local hook_name="$1"

  # Validate hook_name contains only safe characters (path traversal defense)
  [[ ! "$hook_name" =~ ^[a-zA-Z0-9_-]+$ ]] && return 1

  local cooldown_file="${_HAPAI_COOLDOWN_DIR}/${hook_name}.json"

  [[ ! -f "$cooldown_file" ]] && return 1

  local cooldown_until now_epoch until_epoch
  cooldown_until="$(jq -r '.cooldown_until // empty' "$cooldown_file" 2>/dev/null)"
  [[ -z "$cooldown_until" ]] && return 1

  # Validate cooldown_until is ISO 8601 format (injection defense)
  [[ ! "$cooldown_until" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] && return 1

  now_epoch="$(date -u +%s 2>/dev/null)" || return 1
  if until_epoch="$(date -d "$cooldown_until" +%s 2>/dev/null)" && [[ -n "$until_epoch" ]]; then
    : # GNU date (Linux)
  elif until_epoch="$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$cooldown_until" +%s 2>/dev/null)" && [[ -n "$until_epoch" ]]; then
    : # BSD date (macOS)
  else
    until_epoch=0
  fi

  [[ "$now_epoch" -lt "$until_epoch" ]] && return 0 || return 1
}

# Record a denial for cooldown tracking.
# If denials in window_minutes exceed threshold, enters cooldown for cooldown_minutes.
# Config: cooldown.<hook>.threshold / window_minutes / cooldown_minutes
# Usage: cooldown_record "guard-blast-radius"
cooldown_record() {
  local hook_name="$1"

  # Validate hook_name contains only safe characters (path traversal defense)
  [[ ! "$hook_name" =~ ^[a-zA-Z0-9_-]+$ ]] && return 0

  local cooldown_file="${_HAPAI_COOLDOWN_DIR}/${hook_name}.json"

  local enabled
  enabled="$(config_get "cooldown.enabled" "true")"
  [[ "$enabled" != "true" ]] && return 0

  local threshold window_min cooldown_min
  threshold="$(config_get "cooldown.${hook_name}.threshold" "5")"
  window_min="$(config_get "cooldown.${hook_name}.window_minutes" "10")"
  cooldown_min="$(config_get "cooldown.${hook_name}.cooldown_minutes" "30")"

  # Ensure numeric
  [[ ! "$threshold" =~ ^[0-9]+$ ]] && threshold=5
  [[ ! "$window_min" =~ ^[0-9]+$ ]] && window_min=10
  [[ ! "$cooldown_min" =~ ^[0-9]+$ ]] && cooldown_min=30

  local now_epoch
  now_epoch="$(date -u +%s 2>/dev/null)" || return 0
  local window_start=$((now_epoch - window_min * 60))

  # Load existing state or start fresh
  local existing_denials="[]"
  if [[ -f "$cooldown_file" ]]; then
    existing_denials="$(jq -r '.recent_denials // []' "$cooldown_file" 2>/dev/null)" || existing_denials="[]"
  fi

  # Append now, purge entries outside window
  local now_iso
  now_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)" || now_iso="unknown"

  local updated_denials count
  updated_denials="$(echo "$existing_denials" | jq -r \
    --arg now "$now_iso" --argjson ws "$window_start" \
    '[.[] | select(
       (strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) > $ws
     )] + [$now]' 2>/dev/null)" || return 0

  count="$(echo "$updated_denials" | jq -r 'length' 2>/dev/null)" || count=0

  local cooldown_until=""
  if [[ "$count" -ge "$threshold" ]]; then
    cooldown_until="$(_timestamp_future $((cooldown_min * 60)))"
    updated_denials="[]"  # reset after entering cooldown
  fi

  jq -n \
    --arg hook "$hook_name" \
    --argjson denials "$updated_denials" \
    --arg until "$cooldown_until" \
    '{hook: $hook, recent_denials: $denials, cooldown_until: $until}' \
    > "$cooldown_file" 2>/dev/null || true
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

# Install error trap: on any unexpected error, fail-open (exit 0) to never block the host tool.
# NOTE: This trap is installed at the END of the module (after all module-level code runs).
# Module-level code that could fail (e.g., mkdir -p) must have || true guards to avoid
# exiting before the trap is installed. See mkdir at top of file.
trap '_hapai_error_handler' ERR
