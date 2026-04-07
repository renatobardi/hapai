#!/usr/bin/env bash
# hapai/tests/run-tests.sh — Test runner for all hook tests
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAPAI_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# Override HAPAI_HOME for tests
export HAPAI_HOME="$(mktemp -d)"
export HAPAI_ROOT
mkdir -p "$HAPAI_HOME/state"
touch "$HAPAI_HOME/audit.jsonl"

# Copy default config for tests
cp "$HAPAI_ROOT/hapai.defaults.yaml" "$HAPAI_HOME/hapai.yaml"

assert_exit() {
  local expected="$1" actual="$2" test_name="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$actual" == "$expected" ]]; then
    echo -e "  ${GREEN}✓${NC} $test_name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $test_name (expected exit=$expected, got exit=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local output="$1" pattern="$2" test_name="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$output" | grep -qi "$pattern" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $test_name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $test_name (output missing: $pattern)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local output="$1" pattern="$2" test_name="$3"
  TOTAL=$((TOTAL + 1))
  if ! echo "$output" | grep -qi "$pattern" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $test_name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $test_name (output should not contain: $pattern)"
    FAIL=$((FAIL + 1))
  fi
}

# Helper: run a hook with JSON input, capture stdout+stderr and exit code
# Uses temp files to preserve exit code across subshell boundary
_HOOK_EXIT_FILE="$(mktemp)"
_HOOK_OUTPUT_FILE="$(mktemp)"

# Run a hook with JSON input, capture stdout+stderr and exit code
run_hook_check() {
  local hook="$1" input="$2"
  local ec=0
  echo "$input" | bash "$HAPAI_ROOT/hooks/$hook" >"$_HOOK_OUTPUT_FILE" 2>&1 || ec=$?
  echo "$ec" > "$_HOOK_EXIT_FILE"
  cat "$_HOOK_OUTPUT_FILE"
}

get_last_exit() {
  cat "$_HOOK_EXIT_FILE" 2>/dev/null || echo "0"
}

assert_blocked() {
  local output="$1" test_name="$2"
  TOTAL=$((TOTAL + 1))
  local ec
  ec="$(get_last_exit)"
  # exit code 2 = blocked, or "hapai" in stderr output (deny message)
  if [[ "$ec" -eq 2 ]] || echo "$output" | grep -qi "hapai.*block\|blocked\|🛑" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $test_name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $test_name (expected block, exit=$ec)"
    FAIL=$((FAIL + 1))
  fi
}

assert_allowed() {
  local output="$1" test_name="$2"
  TOTAL=$((TOTAL + 1))
  local ec
  ec="$(get_last_exit)"
  if [[ "$ec" -ne 2 ]] && ! echo "$output" | grep -qi "hapai.*block\|blocked\|🛑" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $test_name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $test_name (expected allow, exit=$ec)"
    FAIL=$((FAIL + 1))
  fi
}

# ─── Setup mock git repo ───────────────────────────────────────────────────

MOCK_REPO="$(mktemp -d)"
cd "$MOCK_REPO"
git init -q
git commit --allow-empty -m "init" -q
git checkout -b main -q 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}guard-branch.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: commit on main should be denied
cd "$MOCK_REPO" && git checkout main -q 2>/dev/null
output="$(run_hook_check "pre-tool-use/guard-branch.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: something\""}}')"
assert_blocked "$output" "Blocks commit on main"

# Test: push on main should be denied
output="$(run_hook_check "pre-tool-use/guard-branch.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"}}')"
assert_blocked "$output" "Blocks push on main"

# Test: commit on feature branch should be allowed
cd "$MOCK_REPO" && git checkout -b feat/test -q 2>/dev/null
output="$(run_hook_check "pre-tool-use/guard-branch.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: something\""}}')"
assert_allowed "$output" "Allows commit on feature branch"

# Test: non-git command is ignored
output="$(run_hook_check "pre-tool-use/guard-branch.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"}}')"
assert_allowed "$output" "Ignores non-git commands"

# Test: non-Bash tool is ignored
output="$(run_hook_check "pre-tool-use/guard-branch.sh" '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/test"}}')"
assert_allowed "$output" "Ignores non-Bash tools"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}guard-commit-msg.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: Co-Authored-By should be denied
output="$(run_hook_check "pre-tool-use/guard-commit-msg.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: add button\n\nCo-Authored-By: Claude <noreply@anthropic.com>\""}}')"
assert_blocked "$output" "Blocks Co-Authored-By"

# Test: "Generated with Claude" should be denied
output="$(run_hook_check "pre-tool-use/guard-commit-msg.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: add button\n\nGenerated with Claude Code\""}}')"
assert_blocked "$output" "Blocks Generated with Claude"

# Test: clean commit should be allowed
output="$(run_hook_check "pre-tool-use/guard-commit-msg.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: add login button\""}}')"
assert_allowed "$output" "Allows clean commit message"

# Test: non-commit command ignored
output="$(run_hook_check "pre-tool-use/guard-commit-msg.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin feat/test"}}')"
assert_allowed "$output" "Ignores non-commit commands"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}guard-destructive.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: rm -rf / should be denied
output="$(run_hook_check "pre-tool-use/guard-destructive.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}')"
assert_blocked "$output" "Blocks rm -rf /"

# Test: rm -rf ~ should be denied
output="$(run_hook_check "pre-tool-use/guard-destructive.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf ~"}}')"
assert_blocked "$output" "Blocks rm -rf ~"

# Test: rm -fr . should be denied
output="$(run_hook_check "pre-tool-use/guard-destructive.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -fr ."}}')"
assert_blocked "$output" "Blocks rm -fr ."

# Test: git push --force should be denied
output="$(run_hook_check "pre-tool-use/guard-destructive.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}')"
assert_blocked "$output" "Blocks git push --force"

# Test: git reset --hard should be denied
output="$(run_hook_check "pre-tool-use/guard-destructive.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git reset --hard HEAD~3"}}')"
assert_blocked "$output" "Blocks git reset --hard"

# Test: DROP TABLE should be denied
output="$(run_hook_check "pre-tool-use/guard-destructive.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"psql -c \"DROP TABLE users\""}}')"
assert_blocked "$output" "Blocks DROP TABLE"

# Test: safe rm should be allowed
output="$(run_hook_check "pre-tool-use/guard-destructive.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm temp-file.txt"}}')"
assert_allowed "$output" "Allows safe rm"

# Test: safe git push should be allowed
output="$(run_hook_check "pre-tool-use/guard-destructive.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin feat/test"}}')"
assert_allowed "$output" "Allows safe git push"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}guard-files.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: writing .env should be denied
output="$(run_hook_check "pre-tool-use/guard-files.sh" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/project/.env"}}')"
assert_blocked "$output" "Blocks write to .env"

# Test: writing .env.production should be denied
output="$(run_hook_check "pre-tool-use/guard-files.sh" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/project/.env.production"}}')"
assert_blocked "$output" "Blocks write to .env.production"

# Test: writing .env.example should be allowed
output="$(run_hook_check "pre-tool-use/guard-files.sh" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/project/.env.example"}}')"
assert_allowed "$output" "Allows write to .env.example"

# Test: writing package-lock.json should be denied
output="$(run_hook_check "pre-tool-use/guard-files.sh" '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/project/package-lock.json"}}')"
assert_blocked "$output" "Blocks edit of package-lock.json"

# Test: writing normal file should be allowed
output="$(run_hook_check "pre-tool-use/guard-files.sh" '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/project/src/app.ts"}}')"
assert_allowed "$output" "Allows write to src/app.ts"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}auto-allow-readonly.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Enable auto-allow in test config
echo -e "observability:\n  auto_allow_readonly:\n    enabled: true" > "$HAPAI_HOME/hapai.yaml"

# Test: Read tool should be auto-allowed
output="$(run_hook_check "permission-request/auto-allow-readonly.sh" '{"hook_event_name":"PermissionRequest","tool_name":"Read","tool_input":{"file_path":"/tmp/test"}}')"
assert_contains "$output" "allow" "Auto-allows Read tool"

# Test: Glob tool should be auto-allowed
output="$(run_hook_check "permission-request/auto-allow-readonly.sh" '{"hook_event_name":"PermissionRequest","tool_name":"Glob","tool_input":{"pattern":"**/*.ts"}}')"
assert_contains "$output" "allow" "Auto-allows Glob tool"

# Test: safe bash (ls) should be auto-allowed
output="$(run_hook_check "permission-request/auto-allow-readonly.sh" '{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"ls -la"}}')"
assert_contains "$output" "allow" "Auto-allows ls command"

# Test: git status should be auto-allowed
output="$(run_hook_check "permission-request/auto-allow-readonly.sh" '{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"git status"}}')"
assert_contains "$output" "allow" "Auto-allows git status"

# Test: git push should NOT be auto-allowed (exit 0 with no output = defer)
output="$(run_hook_check "permission-request/auto-allow-readonly.sh" '{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"git push origin main"}}')"
assert_not_contains "$output" "allow" "Does not auto-allow git push"

# Test: Write tool should NOT be auto-allowed
output="$(run_hook_check "permission-request/auto-allow-readonly.sh" '{"hook_event_name":"PermissionRequest","tool_name":"Write","tool_input":{"file_path":"/tmp/test"}}')"
assert_not_contains "$output" "allow" "Does not auto-allow Write tool"

# Restore default config
cp "$HAPAI_ROOT/hapai.defaults.yaml" "$HAPAI_HOME/hapai.yaml"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}sound-alert.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: disabled by default (should exit 0 with no output)
output="$(run_hook_check "notification/sound-alert.sh" '{"hook_event_name":"Notification","tool_name":"","tool_input":{}}')"
assert_allowed "$output" "Sound alert exits cleanly when disabled"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}backup-transcript.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Create a fake transcript for testing
FAKE_TRANSCRIPT="$(mktemp)"
echo '{"role":"user","content":"test"}' > "$FAKE_TRANSCRIPT"

# Test: backs up transcript when file exists
output="$(run_hook_check "pre-compact/backup-transcript.sh" "{\"hook_event_name\":\"PreCompact\",\"transcript_path\":\"$FAKE_TRANSCRIPT\",\"session_id\":\"test123\"}")"
assert_allowed "$output" "Backup transcript exits cleanly"

# Verify backup was created
TOTAL=$((TOTAL + 1))
if ls "$HAPAI_HOME/transcripts/"*.jsonl &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} Transcript backup file created"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Transcript backup file not created"
  FAIL=$((FAIL + 1))
fi

rm -f "$FAKE_TRANSCRIPT"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}require-tests.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Enable require-tests in test config
echo -e "observability:\n  require_tests:\n    enabled: true\n    fail_open: true" > "$HAPAI_HOME/hapai.yaml"

# Create transcript WITHOUT test commands
NO_TEST_TRANSCRIPT="$(mktemp)"
echo '{"tool_input":{"command":"git status"}}' > "$NO_TEST_TRANSCRIPT"

# Test: warns when no tests were run
output="$(run_hook_check "stop/require-tests.sh" "{\"hook_event_name\":\"Stop\",\"transcript_path\":\"$NO_TEST_TRANSCRIPT\"}")"
assert_contains "$output" "test" "Warns when no tests run in session"

# Create transcript WITH test commands
TEST_TRANSCRIPT="$(mktemp)"
echo '{"tool_input":{"command":"vitest run"}}' > "$TEST_TRANSCRIPT"

# Test: allows when tests were found
output="$(run_hook_check "stop/require-tests.sh" "{\"hook_event_name\":\"Stop\",\"transcript_path\":\"$TEST_TRANSCRIPT\"}")"
assert_allowed "$output" "Allows when tests detected in session"

rm -f "$NO_TEST_TRANSCRIPT" "$TEST_TRANSCRIPT"

# Restore default config
cp "$HAPAI_ROOT/hapai.defaults.yaml" "$HAPAI_HOME/hapai.yaml"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}CLI tests${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: hapai help
output="$("$HAPAI_ROOT/bin/hapai" help 2>&1 || true)"
assert_contains "$output" "hapai" "CLI help shows usage"

# Test: hapai version
output="$("$HAPAI_ROOT/bin/hapai" version 2>&1 || true)"
assert_contains "$output" "1.0.0" "CLI shows version"

# Test: hapai validate (before install — should have errors, that's OK)
output="$("$HAPAI_ROOT/bin/hapai" validate 2>&1 || true)"
assert_contains "$output" "validate" "CLI validate runs"

# ═══════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "─────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All $TOTAL tests passed${NC}"
else
  echo -e "${RED}${BOLD}$FAIL/$TOTAL tests failed${NC}"
fi
echo "─────────────────────────────────"

# Cleanup
rm -rf "$MOCK_REPO" "$HAPAI_HOME" "$_HOOK_EXIT_FILE" "$_HOOK_OUTPUT_FILE" 2>/dev/null || true

exit $FAIL
