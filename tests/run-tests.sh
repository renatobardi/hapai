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
echo -e "\n${BOLD}warn-production.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Enable production warning
echo -e "intelligence:\n  production_warning:\n    enabled: true\n    keywords:\n      - prod\n      - deploy\n      - rollback" > "$HAPAI_HOME/hapai.yaml"

# Test: prompt with "deploy" should warn
output="$(run_hook_check "user-prompt-submit/warn-production.sh" '{"hook_event_name":"UserPromptSubmit","user_prompt":"please deploy this to production"}')"
assert_contains "$output" "Production" "Warns on production keyword in prompt"

# Test: prompt without production keywords should pass silently
output="$(run_hook_check "user-prompt-submit/warn-production.sh" '{"hook_event_name":"UserPromptSubmit","user_prompt":"add a login button"}')"
assert_not_contains "$output" "Production" "Allows non-production prompts"

# Test: prompt with "rollback" should warn
output="$(run_hook_check "user-prompt-submit/warn-production.sh" '{"hook_event_name":"UserPromptSubmit","user_prompt":"rollback the last release"}')"
assert_contains "$output" "Production" "Warns on rollback keyword"

cp "$HAPAI_ROOT/hapai.defaults.yaml" "$HAPAI_HOME/hapai.yaml"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}audit-trail.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Enable audit trail
echo -e "intelligence:\n  audit_trail:\n    enabled: true" > "$HAPAI_HOME/hapai.yaml"

# Test: logs a Bash tool execution
output="$(run_hook_check "post-tool-use/audit-trail.sh" '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls -la"},"session_id":"test1234"}')"
assert_allowed "$output" "Audit trail exits cleanly"

# Verify audit-trail.jsonl was written
TOTAL=$((TOTAL + 1))
if [[ -f "$HAPAI_HOME/audit-trail.jsonl" ]] && grep -q '"tool":"Bash"' "$HAPAI_HOME/audit-trail.jsonl" 2>/dev/null; then
  echo -e "  ${GREEN}✓${NC} Audit trail entry written"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Audit trail entry not found"
  FAIL=$((FAIL + 1))
fi

cp "$HAPAI_ROOT/hapai.defaults.yaml" "$HAPAI_HOME/hapai.yaml"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}cost-tracker.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Enable cost tracker
echo -e "intelligence:\n  cost_tracker:\n    enabled: true\n    max_tool_calls: 5\n    max_cost_cents: 100" > "$HAPAI_HOME/hapai.yaml"

# Create transcript with many tool calls (>5 threshold)
COST_TRANSCRIPT="$(mktemp)"
for i in $(seq 1 10); do
  echo "{\"type\":\"tool_use\",\"tool_input\":{\"command\":\"echo $i\"}}" >> "$COST_TRANSCRIPT"
done

# Test: warns when tool calls exceed threshold
output="$(run_hook_check "stop/cost-tracker.sh" "{\"hook_event_name\":\"Stop\",\"transcript_path\":\"$COST_TRANSCRIPT\"}")"
assert_contains "$output" "tool call" "Warns on high tool call count"

rm -f "$COST_TRANSCRIPT"
cp "$HAPAI_ROOT/hapai.defaults.yaml" "$HAPAI_HOME/hapai.yaml"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}load-context.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Enable load-context
echo -e "intelligence:\n  load_context:\n    enabled: true\n    scan_todos: false\n    scan_issues: false" > "$HAPAI_HOME/hapai.yaml"

# Test: loads git context (we're in a git repo from MOCK_REPO)
cd "$MOCK_REPO"
output="$(run_hook_check "session-start/load-context.sh" '{"hook_event_name":"SessionStart","session_id":"ctx123"}')"
assert_contains "$output" "Git" "Loads git context at session start"

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
echo -e "\n${BOLD}Export tests${NC}"
# ═══════════════════════════════════════════════════════════════════════════

EXPORT_DIR="$(mktemp -d)"
cd "$EXPORT_DIR"

# Test: export cursor generates .cursor/rules/hapai.mdc
bash "$HAPAI_ROOT/exporters/export-cursor.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [[ -f ".cursor/rules/hapai.mdc" ]] && grep -q "alwaysApply: true" ".cursor/rules/hapai.mdc"; then
  echo -e "  ${GREEN}✓${NC} Cursor export (.cursor/rules/hapai.mdc with frontmatter)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Cursor export failed"
  FAIL=$((FAIL + 1))
fi

# Test: export copilot generates .github/copilot-instructions.md
bash "$HAPAI_ROOT/exporters/export-copilot.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [[ -f ".github/copilot-instructions.md" ]] && grep -q "Branch Protection" ".github/copilot-instructions.md"; then
  echo -e "  ${GREEN}✓${NC} Copilot export (.github/copilot-instructions.md)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Copilot export failed"
  FAIL=$((FAIL + 1))
fi

# Test: export windsurf generates .windsurf/rules/hapai.md
bash "$HAPAI_ROOT/exporters/export-windsurf.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [[ -f ".windsurf/rules/hapai.md" ]] && grep -q "trigger: always_on" ".windsurf/rules/hapai.md"; then
  echo -e "  ${GREEN}✓${NC} Windsurf export (.windsurf/rules/hapai.md with trigger)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Windsurf export failed"
  FAIL=$((FAIL + 1))
fi

# Test: export trae generates .trae/rules/hapai.md
bash "$HAPAI_ROOT/exporters/export-trae.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [[ -f ".trae/rules/hapai.md" ]] && grep -q "alwaysApply: true" ".trae/rules/hapai.md"; then
  echo -e "  ${GREEN}✓${NC} Trae export (.trae/rules/hapai.md with alwaysApply)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Trae export failed"
  FAIL=$((FAIL + 1))
fi

# Test: export devin generates/updates AGENTS.md with markers
bash "$HAPAI_ROOT/exporters/export-devin.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [[ -f "AGENTS.md" ]] && grep -q "<!-- hapai:start -->" "AGENTS.md" && grep -q "<!-- hapai:end -->" "AGENTS.md"; then
  echo -e "  ${GREEN}✓${NC} Devin export (AGENTS.md with hapai markers)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Devin export failed"
  FAIL=$((FAIL + 1))
fi

# Test: export devin is idempotent (run twice, only one block)
bash "$HAPAI_ROOT/exporters/export-devin.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
marker_count="$(grep -c "<!-- hapai:start -->" "AGENTS.md" 2>/dev/null || echo "0")"
if [[ "$marker_count" -eq 1 ]]; then
  echo -e "  ${GREEN}✓${NC} Devin export idempotent (1 block after 2 runs)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Devin export not idempotent ($marker_count blocks)"
  FAIL=$((FAIL + 1))
fi

# Test: export antigravity generates GEMINI.md + AGENTS.md
rm -f GEMINI.md AGENTS.md
bash "$HAPAI_ROOT/exporters/export-antigravity.sh" > /dev/null 2>&1
TOTAL=$((TOTAL + 1))
if [[ -f "GEMINI.md" ]] && grep -q "<!-- hapai:start -->" "GEMINI.md" && [[ -f "AGENTS.md" ]]; then
  echo -e "  ${GREEN}✓${NC} Antigravity export (GEMINI.md + AGENTS.md)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Antigravity export failed"
  FAIL=$((FAIL + 1))
fi

# Test: all exports share common rules body
TOTAL=$((TOTAL + 1))
common_check=0
grep -q "Branch Protection" ".cursor/rules/hapai.mdc" && \
grep -q "Branch Protection" ".windsurf/rules/hapai.md" && \
grep -q "Branch Protection" ".trae/rules/hapai.md" && \
grep -q "Branch Protection" "AGENTS.md" && \
grep -q "Branch Protection" "GEMINI.md" && \
common_check=1
if [[ $common_check -eq 1 ]]; then
  echo -e "  ${GREEN}✓${NC} All exports share common rules body"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Exports have inconsistent rules"
  FAIL=$((FAIL + 1))
fi

rm -rf "$EXPORT_DIR"
cd "$MOCK_REPO"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}Config parser edge cases${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: config_get resolves correct section when multiple 'enabled' keys exist
COMPLEX_CONFIG="$(mktemp)"
cat > "$COMPLEX_CONFIG" << 'YAML'
guardrails:
  branch_protection:
    enabled: true
    protected: [main, master]
  commit_hygiene:
    enabled: false
  file_protection:
    enabled: true
    protected:
      - ".env"
      - "*.lock"
YAML

# Test config_get in a fresh subshell with controlled config
# We write a helper script to avoid quoting/escaping issues
CONFIG_TEST_SCRIPT="$(mktemp)"
cat > "$CONFIG_TEST_SCRIPT" << 'TESTEOF'
#!/usr/bin/env bash
set -euo pipefail
export HAPAI_HOME="$1"
export _HAPAI_CONFIG="$2"
QUERY="$3"
DEFAULT="$4"
cd "$5"
source hooks/_lib.sh
_HAPAI_INPUT='{}'
echo "$(config_get "$QUERY" "$DEFAULT")"
TESTEOF
chmod +x "$CONFIG_TEST_SCRIPT"

CONFIG_LIST_SCRIPT="$(mktemp)"
cat > "$CONFIG_LIST_SCRIPT" << 'TESTEOF'
#!/usr/bin/env bash
set -euo pipefail
export HAPAI_HOME="$1"
export _HAPAI_CONFIG="$2"
QUERY="$3"
cd "$4"
source hooks/_lib.sh
_HAPAI_INPUT='{}'
config_get_list "$QUERY"
TESTEOF
chmod +x "$CONFIG_LIST_SCRIPT"

# Test: config_get resolves correct section when multiple 'enabled' keys exist
TOTAL=$((TOTAL + 1))
result="$(bash "$CONFIG_TEST_SCRIPT" "$HAPAI_HOME" "$COMPLEX_CONFIG" "guardrails.commit_hygiene.enabled" "default" "$HAPAI_ROOT" 2>/dev/null || echo "error")"
if [[ "$result" == "false" ]]; then
  echo -e "  ${GREEN}✓${NC} config_get returns correct value for nested duplicate keys"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} config_get returned '$result' instead of 'false'"
  FAIL=$((FAIL + 1))
fi

# Test: config_get_list resolves correct list for nested key
TOTAL=$((TOTAL + 1))
result="$(bash "$CONFIG_LIST_SCRIPT" "$HAPAI_HOME" "$COMPLEX_CONFIG" "guardrails.branch_protection.protected" "$HAPAI_ROOT" 2>/dev/null | tr '\n' ',' || echo "error")"
if echo "$result" | grep -q "main"; then
  echo -e "  ${GREEN}✓${NC} config_get_list returns correct list for nested key"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} config_get_list returned '$result'"
  FAIL=$((FAIL + 1))
fi

# Test: config_get returns default for missing key
TOTAL=$((TOTAL + 1))
result="$(bash "$CONFIG_TEST_SCRIPT" "$HAPAI_HOME" "$COMPLEX_CONFIG" "nonexistent.key.here" "mydefault" "$HAPAI_ROOT" 2>/dev/null || echo "error")"
if [[ "$result" == "mydefault" ]]; then
  echo -e "  ${GREEN}✓${NC} config_get returns default for missing key"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} config_get returned '$result' instead of 'mydefault'"
  FAIL=$((FAIL + 1))
fi

rm -f "$COMPLEX_CONFIG" "$CONFIG_TEST_SCRIPT" "$CONFIG_LIST_SCRIPT"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}CLI integration${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: hapai export --all generates files
EXPORT_ALL_DIR="$(mktemp -d)"
cd "$EXPORT_ALL_DIR"
output="$("$HAPAI_ROOT/bin/hapai" export --all 2>&1 || true)"
TOTAL=$((TOTAL + 1))
if echo "$output" | grep -q "Exported to" && [[ -f ".cursor/rules/hapai.mdc" ]] && [[ -f ".windsurf/rules/hapai.md" ]]; then
  echo -e "  ${GREEN}✓${NC} hapai export --all generates all files"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} hapai export --all failed"
  FAIL=$((FAIL + 1))
fi

rm -rf "$EXPORT_ALL_DIR"
cd "$MOCK_REPO"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}Blocklist (advanced state)${NC}"
# ═══════════════════════════════════════════════════════════════════════════

BLOCKLIST_TEST_SCRIPT="$(mktemp)"
cat > "$BLOCKLIST_TEST_SCRIPT" << 'TESTEOF'
#!/usr/bin/env bash
set -euo pipefail
export HAPAI_HOME="$1"
ACTION="$2"
PAT="$3"
TYPE="${4:-general}"
cd "$5"
source hooks/_lib.sh
_HAPAI_INPUT='{}'
find_config
case "$ACTION" in
  add)   blocklist_add "$PAT" "$TYPE" "60" "test block" ;;
  check) blocklist_check "$PAT" "$TYPE" && echo "blocked" || echo "free" ;;
  clean) blocklist_clean ;;
esac
TESTEOF
chmod +x "$BLOCKLIST_TEST_SCRIPT"

# Test: blocklist_add + blocklist_check returns blocked
bash "$BLOCKLIST_TEST_SCRIPT" "$HAPAI_HOME" "add" "test-branch" "branch" "$HAPAI_ROOT" 2>/dev/null
TOTAL=$((TOTAL + 1))
result="$(bash "$BLOCKLIST_TEST_SCRIPT" "$HAPAI_HOME" "check" "test-branch" "branch" "$HAPAI_ROOT" 2>/dev/null || echo "error")"
if [[ "$result" == "blocked" ]]; then
  echo -e "  ${GREEN}✓${NC} blocklist_check returns blocked after blocklist_add"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} blocklist_check returned '$result' (expected 'blocked')"
  FAIL=$((FAIL + 1))
fi

# Test: unknown pattern is not blocked
TOTAL=$((TOTAL + 1))
result="$(bash "$BLOCKLIST_TEST_SCRIPT" "$HAPAI_HOME" "check" "unknown-branch" "branch" "$HAPAI_ROOT" 2>/dev/null || echo "error")"
if [[ "$result" == "free" ]]; then
  echo -e "  ${GREEN}✓${NC} blocklist_check returns free for unknown pattern"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} blocklist_check returned '$result' (expected 'free')"
  FAIL=$((FAIL + 1))
fi

# Test: expired entry is cleaned and returns free
EXPIRED_BLOCKLIST_SCRIPT="$(mktemp)"
cat > "$EXPIRED_BLOCKLIST_SCRIPT" << 'TESTEOF'
#!/usr/bin/env bash
set -euo pipefail
export HAPAI_HOME="$1"
cd "$2"
source hooks/_lib.sh
_HAPAI_INPUT='{}'
find_config
# Add with -1 second duration (already expired)
blocklist_add "expired-branch" "branch" "-1" "should be gone"
blocklist_check "expired-branch" "branch" && echo "blocked" || echo "free"
TESTEOF
chmod +x "$EXPIRED_BLOCKLIST_SCRIPT"
TOTAL=$((TOTAL + 1))
result="$(bash "$EXPIRED_BLOCKLIST_SCRIPT" "$HAPAI_HOME" "$HAPAI_ROOT" 2>/dev/null || echo "error")"
if [[ "$result" == "free" ]]; then
  echo -e "  ${GREEN}✓${NC} blocklist_check returns free for expired entry"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expired blocklist entry not cleaned (returned '$result')"
  FAIL=$((FAIL + 1))
fi

# Test: guard-branch blocks blocklisted branch
cd "$MOCK_REPO"
git checkout main -q 2>/dev/null || true
# The blocklist state is in $HAPAI_HOME/state/blocklist.json (already has test-branch)
# Add main to blocklist
bash "$BLOCKLIST_TEST_SCRIPT" "$HAPAI_HOME" "add" "main" "branch" "$HAPAI_ROOT" 2>/dev/null
output="$(run_hook_check "pre-tool-use/guard-branch.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"test\""}}')"
assert_blocked "$output" "guard-branch blocks blocklisted branch"

# Cleanup blocklist
rm -f "$HAPAI_HOME/state/blocklist.json"
rm -f "$BLOCKLIST_TEST_SCRIPT" "$EXPIRED_BLOCKLIST_SCRIPT"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}Cooldown (advanced state)${NC}"
# ═══════════════════════════════════════════════════════════════════════════

COOLDOWN_TEST_SCRIPT="$(mktemp)"
cat > "$COOLDOWN_TEST_SCRIPT" << 'TESTEOF'
#!/usr/bin/env bash
set -euo pipefail
export HAPAI_HOME="$1"
export _HAPAI_CONFIG="$2"
ACTION="$3"
HOOK="${4:-guard-blast-radius}"
cd "$5"
source hooks/_lib.sh
_HAPAI_INPUT='{}'
case "$ACTION" in
  record) cooldown_record "$HOOK" ;;
  active) cooldown_active "$HOOK" && echo "in_cooldown" || echo "normal" ;;
esac
TESTEOF
chmod +x "$COOLDOWN_TEST_SCRIPT"

# Enable cooldown in test config with threshold=2 for testing
COOLDOWN_CONFIG="$(mktemp)"
cat > "$COOLDOWN_CONFIG" << 'YAML'
cooldown:
  enabled: true
  guard-blast-radius:
    threshold: 2
    window_minutes: 10
    cooldown_minutes: 5
YAML

# Record 2 denials → should enter cooldown
bash "$COOLDOWN_TEST_SCRIPT" "$HAPAI_HOME" "$COOLDOWN_CONFIG" "record" "guard-blast-radius" "$HAPAI_ROOT" 2>/dev/null
bash "$COOLDOWN_TEST_SCRIPT" "$HAPAI_HOME" "$COOLDOWN_CONFIG" "record" "guard-blast-radius" "$HAPAI_ROOT" 2>/dev/null

TOTAL=$((TOTAL + 1))
result="$(bash "$COOLDOWN_TEST_SCRIPT" "$HAPAI_HOME" "$COOLDOWN_CONFIG" "active" "guard-blast-radius" "$HAPAI_ROOT" 2>/dev/null || echo "error")"
if [[ "$result" == "in_cooldown" ]]; then
  echo -e "  ${GREEN}✓${NC} cooldown_active returns true after threshold exceeded"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} cooldown not triggered after threshold (returned '$result')"
  FAIL=$((FAIL + 1))
fi

# Test: hook not in cooldown returns normal
TOTAL=$((TOTAL + 1))
result="$(bash "$COOLDOWN_TEST_SCRIPT" "$HAPAI_HOME" "$COOLDOWN_CONFIG" "active" "guard-files" "$HAPAI_ROOT" 2>/dev/null || echo "error")"
if [[ "$result" == "normal" ]]; then
  echo -e "  ${GREEN}✓${NC} cooldown_active returns normal for hook with no denials"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} unexpected cooldown state (returned '$result')"
  FAIL=$((FAIL + 1))
fi

# Cleanup
rm -f "$COOLDOWN_CONFIG" "$COOLDOWN_TEST_SCRIPT"
rm -rf "$HAPAI_HOME/state/cooldown"
mkdir -p "$HAPAI_HOME/state/cooldown"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}Flow dispatcher${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: dispatcher exits cleanly when flows.enabled=false (default)
cd "$MOCK_REPO"
output="$(run_hook_check "pre-tool-use/flow-dispatcher.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"test\""}}')"
assert_allowed "$output" "Flow dispatcher exits cleanly when flows.enabled=false"

# Test: flow with enabled=true and gate=block denies on step failure
FLOW_CONFIG="$(mktemp)"
cat > "$FLOW_CONFIG" << 'YAML'
flows:
  enabled: true
  active: test_flow
  test_flow:
    event: PreToolUse
    matcher: "Bash(git commit*)"
    steps:
      - hook: guard-branch
        gate: block
YAML

FLOW_TEST_SCRIPT="$(mktemp)"
cat > "$FLOW_TEST_SCRIPT" << 'TESTEOF'
#!/usr/bin/env bash
export HAPAI_HOME="$1"
export _HAPAI_CONFIG="$2"
INPUT="$3"
HAPAI_HOOK_ROOT="$4/hooks"
ec=0
echo "$INPUT" | bash "$4/hooks/pre-tool-use/flow-dispatcher.sh" >/tmp/flow_out 2>&1 || ec=$?
echo "$ec" > /tmp/flow_exit
cat /tmp/flow_out
TESTEOF
chmod +x "$FLOW_TEST_SCRIPT"

# Flow with guard-branch step + commit on main = should deny (exit 2)
cd "$MOCK_REPO"
git checkout main -q 2>/dev/null || true
bash "$FLOW_TEST_SCRIPT" "$HAPAI_HOME" "$FLOW_CONFIG" \
  '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"test\""}}' \
  "$HAPAI_ROOT" 2>/dev/null || true
TOTAL=$((TOTAL + 1))
flow_exit="$(cat /tmp/flow_exit 2>/dev/null || echo "0")"
if [[ "$flow_exit" -eq 2 ]]; then
  echo -e "  ${GREEN}✓${NC} Flow gate=block propagates deny from guard-branch"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} Flow gate=block did not propagate deny (exit=$flow_exit)"
  FAIL=$((FAIL + 1))
fi

# Test: flow config_get_flow_steps parses steps correctly
FLOW_STEPS_SCRIPT="$(mktemp)"
cat > "$FLOW_STEPS_SCRIPT" << 'TESTEOF'
#!/usr/bin/env bash
export HAPAI_HOME="$1"
export _HAPAI_CONFIG="$2"
cd "$3"
source hooks/_lib.sh
_HAPAI_INPUT='{}'
config_get_flow_steps "test_flow"
TESTEOF
chmod +x "$FLOW_STEPS_SCRIPT"

TOTAL=$((TOTAL + 1))
result="$(bash "$FLOW_STEPS_SCRIPT" "$HAPAI_HOME" "$FLOW_CONFIG" "$HAPAI_ROOT" 2>/dev/null || echo "error")"
if echo "$result" | jq -e '.hook == "guard-branch"' &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} config_get_flow_steps parses flow steps correctly"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} config_get_flow_steps returned: $result"
  FAIL=$((FAIL + 1))
fi

rm -f "$FLOW_CONFIG" "$FLOW_TEST_SCRIPT" "$FLOW_STEPS_SCRIPT" /tmp/flow_out /tmp/flow_exit 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}CLI block/unblock/blocklist${NC}"
# ═══════════════════════════════════════════════════════════════════════════

# Test: hapai block creates entry
output="$(HAPAI_HOME="$HAPAI_HOME" "$HAPAI_ROOT/bin/hapai" block "feature/bad" --type branch --for 30m --reason "test" 2>&1 || true)"
TOTAL=$((TOTAL + 1))
if echo "$output" | grep -q "Blocked" && [[ -f "$HAPAI_HOME/state/blocklist.json" ]]; then
  echo -e "  ${GREEN}✓${NC} hapai block creates blocklist entry"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} hapai block failed (output: $output)"
  FAIL=$((FAIL + 1))
fi

# Test: hapai blocklist shows entry
output="$(HAPAI_HOME="$HAPAI_HOME" "$HAPAI_ROOT/bin/hapai" blocklist 2>&1 || true)"
TOTAL=$((TOTAL + 1))
if echo "$output" | grep -q "feature/bad"; then
  echo -e "  ${GREEN}✓${NC} hapai blocklist shows active blocks"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} hapai blocklist did not show entry (output: $output)"
  FAIL=$((FAIL + 1))
fi

# Test: hapai unblock removes entry
output="$(HAPAI_HOME="$HAPAI_HOME" "$HAPAI_ROOT/bin/hapai" unblock "feature/bad" 2>&1 || true)"
TOTAL=$((TOTAL + 1))
if echo "$output" | grep -q "Unblocked"; then
  echo -e "  ${GREEN}✓${NC} hapai unblock removes entry"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} hapai unblock failed (output: $output)"
  FAIL=$((FAIL + 1))
fi

# Test: hapai list-hooks runs without error
output="$(HAPAI_HOME="$HAPAI_HOME" "$HAPAI_ROOT/bin/hapai" list-hooks 2>&1 || true)"
TOTAL=$((TOTAL + 1))
if echo "$output" | grep -q "list-hooks"; then
  echo -e "  ${GREEN}✓${NC} hapai list-hooks runs without error"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} hapai list-hooks failed (output: $output)"
  FAIL=$((FAIL + 1))
fi

# Cleanup
rm -f "$HAPAI_HOME/state/blocklist.json"

# ═══════════════════════════════════════════════════════════════════════════
echo -e "\n${BOLD}guard-branch-rules.sh${NC}"
# ═══════════════════════════════════════════════════════════════════════════

BRANCH_RULES_CONFIG="$(mktemp)"
cat > "$BRANCH_RULES_CONFIG" << 'YAML'
guardrails:
  branch_protection:
    enabled: true
    protected: [main, master]
  branch_rules:
    enabled: true
    require_from_protected: true
    require_description: true
    fail_open: false
    allowed_prefixes:
      - feat
      - fix
      - chore
YAML

BRANCH_RULES_CONFIG_OPEN="$(mktemp)"
cat > "$BRANCH_RULES_CONFIG_OPEN" << 'YAML'
guardrails:
  branch_protection:
    enabled: true
    protected: [main, master]
  branch_rules:
    enabled: true
    require_from_protected: false
    require_description: true
    fail_open: false
    allowed_prefixes:
      - feat
      - fix
      - chore
YAML

# Create a feature branch to test origin rule
cd "$MOCK_REPO" && git checkout -b feat/old-work -q 2>/dev/null || git checkout feat/old-work -q 2>/dev/null

# Non-Bash tool → allow
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}')"
assert_allowed "$output" "branch-rules: ignores non-Bash tools"

# Config explicitly disabled → allow
BRANCH_RULES_DISABLED="$(mktemp)"
cat > "$BRANCH_RULES_DISABLED" << 'YAML'
guardrails:
  branch_rules:
    enabled: false
YAML
export _HAPAI_CONFIG="$BRANCH_RULES_DISABLED"
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout -b bad-name"}}')"
assert_allowed "$output" "branch-rules: allows all when disabled"
unset _HAPAI_CONFIG
rm -f "$BRANCH_RULES_DISABLED"

export _HAPAI_CONFIG="$BRANCH_RULES_CONFIG"

# Non-creation command → allow
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin feat/old-work"}}')"
assert_allowed "$output" "branch-rules: ignores non-branch-creation commands"

# Name without prefix → block
cd "$MOCK_REPO" && git checkout main -q 2>/dev/null
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout -b my-feature"}}')"
assert_blocked "$output" "branch-rules: blocks branch name without allowed prefix"

# Name with prefix but empty description → block
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout -b feat/"}}')"
assert_blocked "$output" "branch-rules: blocks branch with prefix but no description"

# Name with uppercase in description → block
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout -b feat/MyFeature"}}')"
assert_blocked "$output" "branch-rules: blocks branch with uppercase description"

# Valid name from main → allow
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout -b feat/add-login"}}')"
assert_allowed "$output" "branch-rules: allows valid branch from main"

# Valid name from main via git switch -c → allow
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git switch -c fix/null-deref"}}')"
assert_allowed "$output" "branch-rules: allows git switch -c from main"

# Valid name but from feature branch → block (origin rule)
cd "$MOCK_REPO" && git checkout feat/old-work -q 2>/dev/null
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout -b feat/new-feature"}}')"
assert_blocked "$output" "branch-rules: blocks branch creation from a feature branch"
assert_contains "$output" "main\|protected\|checkout main" "branch-rules: block message includes recovery instruction"

# require_from_protected=false → allows from feature branch
export _HAPAI_CONFIG="$BRANCH_RULES_CONFIG_OPEN"
cd "$MOCK_REPO" && git checkout feat/old-work -q 2>/dev/null
output="$(run_hook_check "pre-tool-use/guard-branch-rules.sh" '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git checkout -b feat/new-feature"}}')"
assert_allowed "$output" "branch-rules: allows from feature branch when require_from_protected=false"

unset _HAPAI_CONFIG
rm -f "$BRANCH_RULES_CONFIG" "$BRANCH_RULES_CONFIG_OPEN" 2>/dev/null || true
cd "$MOCK_REPO" && git checkout main -q 2>/dev/null || true

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
