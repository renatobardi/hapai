#!/usr/bin/env bash
# hapai/hooks/stop/cost-tracker.sh
# Estimates session cost based on tool call count and transcript size.
# Warns if session exceeded configured thresholds.
# Event: Stop | Timeout: 10s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Check if enabled
enabled="$(config_get "intelligence.cost_tracker.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

# Get transcript path
transcript_path="$(get_field '.transcript_path')"
[[ -z "$transcript_path" || ! -f "$transcript_path" ]] && exit 0

# Count tool calls in transcript
# Search for "type":"tool_use" to avoid false positives in strings/comments
tool_calls=0
if [[ -f "$transcript_path" ]]; then
  tool_calls="$(grep -c '"type"[[:space:]]*:[[:space:]]*"tool_use"' "$transcript_path" 2>/dev/null || echo "0")"
fi

# Get transcript size
transcript_lines="$(wc -l < "$transcript_path" 2>/dev/null | tr -d ' ')"
transcript_bytes="$(wc -c < "$transcript_path" 2>/dev/null | tr -d ' ')"
transcript_kb=$((transcript_bytes / 1024))

# Rough cost estimation based on Claude Code pricing model:
# ~$0.01 per 1K input tokens, ~$0.03 per 1K output tokens
# Rough heuristic: 1KB transcript ≈ 250 tokens, each tool call ≈ 500 tokens round-trip
estimated_tokens=$(( (transcript_kb * 250) + (tool_calls * 500) ))
# Estimate in cents (input-heavy: ~$0.01/1K tokens average)
estimated_cents=$(( estimated_tokens / 100 ))

# Format as dollars
estimated_dollars="$(printf '$%d.%02d' $((estimated_cents / 100)) $((estimated_cents % 100)))"

# Get thresholds from config
max_tool_calls="$(config_get "intelligence.cost_tracker.max_tool_calls" "200")"
max_cost_cents="$(config_get "intelligence.cost_tracker.max_cost_cents" "500")"

# Build summary
summary="Session: $tool_calls tool calls, ${transcript_kb}KB transcript (~${estimated_tokens} tokens, ~${estimated_dollars})"

# Log session stats to state
state_set "cost-tracker.last_session_calls" "$tool_calls"
state_set "cost-tracker.last_session_tokens" "$estimated_tokens"
state_set "cost-tracker.last_session_cost_cents" "$estimated_cents"

# Accumulate total across sessions
total_calls="$(state_get "cost-tracker.total_calls" "0")"
total_cost="$(state_get "cost-tracker.total_cost_cents" "0")"
state_set "cost-tracker.total_calls" "$((total_calls + tool_calls))"
state_set "cost-tracker.total_cost_cents" "$((total_cost + estimated_cents))"

# Check thresholds
warnings=""
if [[ "$tool_calls" -gt "$max_tool_calls" ]]; then
  warnings="$warnings High tool call count ($tool_calls > $max_tool_calls threshold)."
fi
if [[ "$estimated_cents" -gt "$max_cost_cents" ]]; then
  warnings="$warnings Estimated cost ($estimated_dollars) exceeds threshold (\$$(printf '%d.%02d' $((max_cost_cents / 100)) $((max_cost_cents % 100))))."
fi

if [[ -n "$warnings" ]]; then
  state_increment "cost-tracker.warn_count"
  warn "hapai cost: $summary.$warnings"
else
  audit_log "cost" "$summary"
fi

exit 0
