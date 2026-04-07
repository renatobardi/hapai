#!/usr/bin/env bash
# hapai/hooks/permission-request/auto-allow-readonly.sh
# Auto-approves read-only tool operations (Read, Glob, Grep, LS).
# Reduces permission prompts without sacrificing safety.
# Also auto-approves safe Bash commands (ls, pwd, echo, cat, head, tail, wc, git log/status/diff).
# Event: PermissionRequest | Timeout: 5s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Check if enabled
enabled="$(config_get "observability.auto_allow_readonly.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

tool_name="$(get_tool_name)"

# Auto-approve read-only tools
case "$tool_name" in
  Read|Glob|Grep|LS|NotebookRead|ListMcpResourcesTool|ReadMcpResourceTool)
    jq -n '{hookSpecificOutput: {hookEventName: "PermissionRequest", permissionDecision: "allow"}}'
    audit_log "auto-allow" "Read-only tool: $tool_name"
    exit 0
    ;;
esac

# Auto-approve safe Bash commands (read-only commands that don't modify state)
if [[ "$tool_name" == "Bash" ]]; then
  command="$(get_field '.tool_input.command')"
  [[ -z "$command" ]] && exit 0

  # Extract the first command (before any pipe/chain)
  first_cmd="$(echo "$command" | sed -E 's/\s*[|;&].*//' | sed 's/^\s*//' | awk '{print $1}')"

  # List of safe read-only commands
  case "$first_cmd" in
    ls|pwd|echo|cat|head|tail|wc|file|which|type|whereis|whoami|date|uname|hostname)
      jq -n '{hookSpecificOutput: {hookEventName: "PermissionRequest", permissionDecision: "allow"}}'
      audit_log "auto-allow" "Safe bash: $first_cmd"
      exit 0
      ;;
    git)
      # Allow read-only git commands
      git_subcmd="$(echo "$command" | awk '{print $2}')"
      case "$git_subcmd" in
        log|status|diff|show|branch|tag|remote|stash\ list|rev-parse|describe|shortlog|blame)
          jq -n '{hookSpecificOutput: {hookEventName: "PermissionRequest", permissionDecision: "allow"}}'
          audit_log "auto-allow" "Safe git: git $git_subcmd"
          exit 0
          ;;
      esac
      ;;
    find|grep|rg|fd|tree|du|df|stat|realpath|readlink|basename|dirname)
      jq -n '{hookSpecificOutput: {hookEventName: "PermissionRequest", permissionDecision: "allow"}}'
      audit_log "auto-allow" "Safe bash: $first_cmd"
      exit 0
      ;;
    npm|pnpm|yarn|bun)
      # Allow read-only package manager commands
      subcmd="$(echo "$command" | awk '{print $2}')"
      case "$subcmd" in
        list|ls|outdated|view|info|show|why|audit|pack\ --dry-run)
          jq -n '{hookSpecificOutput: {hookEventName: "PermissionRequest", permissionDecision: "allow"}}'
          audit_log "auto-allow" "Safe pkg: $first_cmd $subcmd"
          exit 0
          ;;
      esac
      ;;
    python|python3|node)
      # Allow version checks
      if echo "$command" | grep -qE '^\s*(python3?|node)\s+--version\s*$'; then
        jq -n '{hookSpecificOutput: {hookEventName: "PermissionRequest", permissionDecision: "allow"}}'
        audit_log "auto-allow" "Version check: $first_cmd"
        exit 0
      fi
      ;;
  esac
fi

# Not a recognized read-only operation — defer to normal permission flow
exit 0
