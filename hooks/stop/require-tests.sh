#!/usr/bin/env bash
# hapai/hooks/stop/require-tests.sh
# Warns or blocks session completion if no tests were run during the session.
# Checks the transcript for test command executions (vitest, pytest, jest, etc.).
# Event: Stop | Timeout: 10s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Check if enabled
enabled="$(config_get "observability.require_tests.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

# Get transcript path from input
transcript_path="$(get_field '.transcript_path')"
[[ -z "$transcript_path" || ! -f "$transcript_path" ]] && exit 0

# Get configured test commands
test_commands=()
while IFS= read -r cmd; do
  [[ -n "$cmd" ]] && test_commands+=("$cmd")
done <<< "$(config_get_list "observability.require_tests.test_commands")"

# Default test commands if none configured
if [[ ${#test_commands[@]} -eq 0 ]]; then
  test_commands=("vitest" "pytest" "jest" "mocha" "cargo test" "go test" "npm test" "pnpm test" "yarn test")
fi

# Search transcript for any test execution
# The transcript is JSONL — search for Bash tool_input.command containing test commands
found_test=0
for cmd in "${test_commands[@]}"; do
  if grep -q "\"command\".*${cmd}" "$transcript_path" 2>/dev/null; then
    found_test=1
    break
  fi
done

if [[ $found_test -eq 0 ]]; then
  fail_open="$(config_get "observability.require_tests.fail_open" "true")"
  state_increment "require-tests.warn_count"

  if [[ "$fail_open" == "true" ]]; then
    warn "hapai: No tests were run during this session. Consider running tests before finishing."
  else
    deny "hapai: Session blocked — no tests were run. Run your test suite before completing."
  fi
fi

audit_log "allow" "Tests detected in session"
exit 0
