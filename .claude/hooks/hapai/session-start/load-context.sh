#!/usr/bin/env bash
# hapai/hooks/session-start/load-context.sh
# Loads contextual information at session start (git status, TODOs, open issues).
# Provides Claude with project state awareness before the user's first prompt.
# Event: SessionStart | Timeout: 10s

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../_lib.sh"

read_input

# Check if enabled
enabled="$(config_get "intelligence.load_context.enabled" "false")"
[[ "$enabled" != "true" ]] && exit 0

context_parts=()

# 1. Git status (branch, uncommitted changes, recent commits)
if git rev-parse --is-inside-work-tree &>/dev/null; then
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
  dirty_count="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  recent_commits="$(git log --oneline -3 2>/dev/null | tr '\n' '; ' | head -c 200)"

  git_ctx="Git: branch=$branch"
  [[ "$dirty_count" -gt 0 ]] && git_ctx="$git_ctx, $dirty_count uncommitted files"
  [[ -n "$recent_commits" ]] && git_ctx="$git_ctx. Recent: $recent_commits"

  context_parts+=("$git_ctx")
fi

# 2. TODO/FIXME count in codebase (quick scan)
load_todos="$(config_get "intelligence.load_context.scan_todos" "true")"
if [[ "$load_todos" == "true" ]]; then
  todo_count=0
  if command -v rg &>/dev/null; then
    todo_count="$(rg -c 'TODO|FIXME|HACK|XXX' --type-not binary -g '!node_modules' -g '!.git' -g '!dist' -g '!build' 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')"
  elif command -v grep &>/dev/null; then
    todo_count="$(grep -rn 'TODO\|FIXME\|HACK\|XXX' --include='*.ts' --include='*.js' --include='*.py' --include='*.sh' --include='*.svelte' . 2>/dev/null | grep -v node_modules | grep -v '.git' | wc -l | tr -d ' ')"
  fi
  [[ "$todo_count" -gt 0 ]] && context_parts+=("TODOs: $todo_count items (TODO/FIXME/HACK/XXX)")
fi

# 3. Open GitHub issues (if gh is available)
load_issues="$(config_get "intelligence.load_context.scan_issues" "false")"
if [[ "$load_issues" == "true" ]] && command -v gh &>/dev/null; then
  issues="$(gh issue list --limit 5 --state open --json number,title 2>/dev/null | jq -r '.[] | "#\(.number) \(.title)"' 2>/dev/null | tr '\n' '; ' | head -c 300)"
  [[ -n "$issues" ]] && context_parts+=("Open issues: $issues")
fi

# 4. hapai state summary
deny_total=0
# Use nullglob to handle case where no *.deny_count files exist
shopt -s nullglob 2>/dev/null || true
for f in "$HAPAI_STATE_DIR/"*.deny_count; do
  [[ -f "$f" ]] || continue
  val="$(cat "$f" 2>/dev/null || echo 0)"
  deny_total=$((deny_total + val))
done
shopt -u nullglob 2>/dev/null || true
[[ $deny_total -gt 0 ]] && context_parts+=("hapai: $deny_total total blocks across sessions")

# Build context message
if [[ ${#context_parts[@]} -gt 0 ]]; then
  context_msg="$(printf '%s\n' "${context_parts[@]}" | tr '\n' ' | ' | sed 's/ | $//')"

  jq -n \
    --arg ctx "[hapai context] $context_msg" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'

  audit_log "context" "Loaded: ${#context_parts[@]} sections"
fi

exit 0
