# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is hapai

hapai is a deterministic guardrails system for AI coding assistants (Claude Code, Cursor, Copilot). It enforces security rules via shell-based hooks that intercept tool calls and block violations **before execution** — not probabilistic prompts that can be ignored. Pure Bash, only external dependency is `jq`.

## Running Tests

```bash
# Run all tests
bash tests/run-tests.sh

# Run tests for a specific guard (e.g., branch protection)
bash tests/run-tests.sh 2>&1 | grep -A 20 "guard-branch.sh"

# Run tests and show summary only
bash tests/run-tests.sh 2>&1 | tail -5
```

Tests are bash-based assertions in a single file (no test framework). Each hook is tested via `run_hook_check()` which pipes JSON input to the hook and captures exit code.

## Development Workflow

### Adding a New Guardrail

1. **Create the hook script** in `hooks/pre-tool-use/guard-{name}.sh`:
   ```bash
   #!/usr/bin/env bash
   source "${SCRIPT_DIR}/../_lib.sh"
   
   read_input
   
   # Check if enabled
   enabled="$(config_get "guardrails.{name}.enabled" "true")"
   [[ "$enabled" != "true" ]] && exit 0
   
   # Your logic here...
   # Exit 0 to allow, or call deny() to block with exit 2
   ```

2. **Source `_lib.sh`** for utilities:
   - `read_input` — parse stdin JSON
   - `get_field ".path"` — extract JSON field
   - `config_get "path.to.config" "default"` — read config (with YAML fallback)
   - `deny "message"` — exit 2 and log to stderr
   - `state_increment "counter.name"` — increment per-hook counter
   - `blocklist_check "value" "type"` — check temporary blocklist

3. **Add config keys** to `hapai.defaults.yaml`:
   ```yaml
   guardrails:
     {name}:
       enabled: true
       fail_open: false
   ```

4. **Write tests** in `tests/run-tests.sh`:
   - Use `run_hook_check "pre-tool-use/guard-{name}.sh" '{json}'`
   - Use `assert_blocked "$output" "test description"`
   - Use `assert_allowed "$output" "test description"`

5. **Register in templates** if needed:
   - Add hook path to `templates/settings.hooks.json` (optional if auto-discovered)

### Testing Hooks Locally

```bash
# Test a hook manually with JSON input
cat <<'EOF' | bash hooks/pre-tool-use/guard-branch.sh
{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m test"}}
EOF

# Check exit code
echo $?

# Run hook against your current repo
cd /path/to/test/repo
cat <<'EOF' | bash ~/hapai/hooks/pre-tool-use/guard-branch.sh
{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"}}
EOF
```

### Linting & Code Quality

```bash
# shellcheck compliance (local development)
shellcheck hooks/**/*.sh bin/hapai

# Format bash code (if prettier + plugin is installed)
prettier --write --parser bash hooks/**/*.sh

# Check for common bash issues
bash -n hooks/pre-tool-use/guard-branch.sh  # syntax check
```

## Architecture

**CLI** (`bin/hapai`) — install/uninstall/validate/status/audit commands. Copies hooks to `~/.hapai/hooks/`, registers them in Claude Code's `~/.claude/settings.json`, and injects rules into CLAUDE.md.

**Hook lifecycle** — Claude Code triggers hooks at 5 points:
- **SessionStart** — Load context (git status, TODOs)
- **PreToolUse** (7s timeout) — Guard scripts block violations before execution
- **PostToolUse** (5s timeout) — Automations (checkpoint, format, lint, audit trail)
- **PreCompact** — Backup transcripts before context compression
- **Stop** (10s timeout) — Session-end cleanup (squash checkpoints, verify tests, cost tracking)

Each hook reads JSON from stdin, sources `hooks/_lib.sh` for utilities, then exits 0 (allow) or 2 (deny). Hooks never crash the host tool — all internal errors exit 0 (fail-open).

**Hook dispatcher pattern** — `hooks/pre-tool-use/flow-dispatcher.sh` (new in v1.3) orchestrates multiple guards in sequence. This allows complex logic like "run guard-branch, but skip guard-destructive if we're not on main". Reduces hook registration overhead.

**Key modules:**
- `hooks/_lib.sh` — Shared library: YAML config loading (hand-parsed, no external tools), JSON I/O via `jq`, audit logging, state counters, git utilities
- `hooks/pre-tool-use/` — Guardrails that block violations (branch protection, destructive commands, file protection, commit hygiene, blast radius, uncommitted changes)
- `hooks/post-tool-use/` — Automations after execution (auto-checkpoint, auto-format, auto-lint, audit trail)
- `hooks/stop/` — Session-end hooks (squash checkpoints, require tests, cost tracker)
- `hooks/session-start/` — Context loading (git status, open issues)
- `hooks/notification/` — Sound alerts on violations
- `hooks/permission-request/` — Auto-approve read-only operations
- `hooks/user-prompt-submit/` — Production warnings, token tracking
- `exporters/` — Generate rules for other tools (Cursor, Copilot, Windsurf, Devin, Antigravity)
- `templates/settings.hooks.json` — Hook registration template for Claude Code
- `hapai.defaults.yaml` — Default config; users override with `hapai.yaml` in project root

**Config resolution:** project `hapai.yaml` → global `~/.hapai/hapai.yaml` → `hapai.defaults.yaml`

**State & Observability:**
- Audit log at `~/.hapai/audit.jsonl` (append-only JSONL, immutable)
- Per-hook counters at `~/.hapai/state/{hook-name}.count`
- Cloud sync (v1.3+): `hapai sync` streams audit logs to Cloud Storage via OIDC + Cloud Functions

## Conventions

- All scripts use `set -euo pipefail`
- Exit codes follow Claude Code hook API: `0` = allow, `2` = deny
- JSON output constructed via `jq -n` (safe against injection)
- User-facing messages go to stderr, structured output to stdout
- Hook timeouts: PreToolUse=7s, PostToolUse=5s, Stop=10s
- Each guardrail is one file, one concern, 50-100 LOC
- `fail_open: true` means warn but don't block; `false` means hard deny
- Temporary blocklist is queried via `blocklist_check "value" "type"` (persists across session)
- Config values are read with `config_get "path" "default"` (handles YAML parsing + fallback)
