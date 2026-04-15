#!/usr/bin/env bash
# hapai/hooks/user-prompt-submit/warn-production.sh
# Warns when user prompts contain production-related keywords (prod, deploy, etc.).
# Adds a reminder to double-check before taking production actions.
# Event: UserPromptSubmit | Timeout: 5s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Check if enabled
enabled="$(config_get "intelligence.production_warning.enabled" "true")"
[[ "$enabled" != "true" ]] && exit 0

# Get the user prompt from input
user_prompt="$(get_field '.user_prompt')"
# Fallback: some versions use .content or .prompt
[[ -z "$user_prompt" ]] && user_prompt="$(get_field '.content')"
[[ -z "$user_prompt" ]] && user_prompt="$(get_field '.prompt')"
[[ -z "$user_prompt" ]] && exit 0

prompt_lower="$(echo "$user_prompt" | tr '[:upper:]' '[:lower:]')"

# Get keywords from config (or use defaults)
keywords=()
while IFS= read -r kw; do
  [[ -n "$kw" ]] && keywords+=("$kw")
done <<< "$(config_get_list "intelligence.production_warning.keywords")"

if [[ ${#keywords[@]} -eq 0 ]]; then
  keywords=("prod" "production" "deploy" "deployment" "--prod" "deploy-prod" "release" "hotfix" "rollback")
fi

# Check if prompt contains any production keyword (word boundary aware)
matched_keyword=""
for kw in "${keywords[@]}"; do
  kw_lower="$(echo "$kw" | tr '[:upper:]' '[:lower:]')"
  if echo "$prompt_lower" | grep -qwi "$kw_lower" 2>/dev/null; then
    matched_keyword="$kw"
    break
  fi
done

if [[ -n "$matched_keyword" ]]; then
  state_increment "warn-production.warn_count"

  # Use jq for safe JSON output
  jq -n \
    --arg ctx "hapai: Production keyword detected ('$matched_keyword'). Double-check before taking production actions. Make sure you're on the right branch and environment." \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

  audit_log "warn" "Production keyword: $matched_keyword"
  exit 0
fi

exit 0
