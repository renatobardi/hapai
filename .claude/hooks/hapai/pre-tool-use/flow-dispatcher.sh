#!/usr/bin/env bash
# hapai/hooks/pre-tool-use/flow-dispatcher.sh
# Executes a configured sequence of hooks (a "flow") with conditional gate logic.
#
# Gates:
#   block (default) — if step denies (exit 2), chain stops and propagates deny
#   warn            — if step denies, converts to warning and continues chain
#   skip            — step is skipped if any previous step warned or denied
#
# Config (hapai.yaml):
#   flows:
#     pre_commit_review:
#       event: PreToolUse
#       matcher: "Bash(git commit*)"
#       steps:
#         - hook: guard-branch
#           gate: block
#         - hook: guard-commit-msg
#           gate: block
#         - hook: guard-blast-radius
#           gate: warn
#
# Event: PreToolUse | Timeout: 7s

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAPAI_HOOK_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/../_lib.sh"

read_input

enabled="$(config_get "flows.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

active_flow="$(config_get "flows.active" "pre_commit_review")"
[[ -z "$active_flow" ]] && exit 0

# Check if this hook event applies to the configured flow
flow_event="$(config_get "flows.${active_flow}.event" "PreToolUse")"
hook_event="$(get_hook_event)"
[[ "$flow_event" != "$hook_event" ]] && exit 0

# Execute each step in the flow
_FLOW_DENIED=0
_FLOW_WARNED=0
_FLOW_WARNINGS=""

while IFS= read -r step_json; do
  [[ -z "$step_json" ]] && continue

  hook_name="$(echo "$step_json" | jq -r '.hook // empty' 2>/dev/null)"
  gate="$(echo "$step_json" | jq -r '.gate // "block"' 2>/dev/null)"

  [[ -z "$hook_name" ]] && continue

  # Validate hook_name is safe (alphanumeric + underscore/dash only, no path traversal)
  if [[ ! "$hook_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    audit_log "deny" "flow '${active_flow}' step has unsafe hook name: '${hook_name}'"
    continue
  fi

  # skip gate: bypass this step if any previous step warned or denied (then recovered)
  if [[ "$gate" == "skip" && $_FLOW_WARNED -eq 1 ]]; then
    continue
  fi

  hook_path="${HAPAI_HOOK_ROOT}/pre-tool-use/${hook_name}.sh"

  # flow_run_step is defined in _lib.sh — sets _FLOW_DENIED/_FLOW_WARNED/_FLOW_WARNINGS
  flow_run_step "$hook_path" "$gate"

  # Hard denial — stop chain immediately
  if [[ $_FLOW_DENIED -eq 1 ]]; then
    audit_log "deny" "flow '${active_flow}' denied at step '${hook_name}' (gate: ${gate})"
    exit 2
  fi

done <<< "$(config_get_flow_steps "$active_flow")"

# All steps passed — emit accumulated warnings if any
if [[ $_FLOW_WARNED -eq 1 && -n "$_FLOW_WARNINGS" ]]; then
  local_event="$(get_hook_event 2>/dev/null || echo "PreToolUse")"
  jq -n \
    --arg event "$local_event" \
    --arg ctx "$(echo "$_FLOW_WARNINGS" | sed 's/[[:space:]]*$//')" \
    '{hookSpecificOutput: {hookEventName: $event, permissionDecision: "allow", additionalContext: $ctx}}'
  audit_log "warn" "flow '${active_flow}' completed with warnings"
  exit 0
fi

audit_log "allow" "flow '${active_flow}' passed"
exit 0
