# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is hapai

hapai is a deterministic guardrails system for AI coding assistants (Claude Code, Cursor, Copilot). It enforces security rules via shell-based hooks that intercept tool calls and block violations **before execution** — not probabilistic prompts that can be ignored. Pure Bash, only external dependency is `jq`.

## Running Tests

```bash
bash tests/run-tests.sh
```

Tests are bash-based assertions in a single file. No test framework — just `assert_*` functions.

## Architecture

**CLI** (`bin/hapai`) — install/uninstall/validate/status/audit commands. Copies hooks to `~/.hapai/hooks/`, registers them in Claude Code's `~/.claude/settings.json`, and injects rules into CLAUDE.md.

**Hook lifecycle** — Claude Code triggers hooks via JSON on stdin. Each hook reads tool name/command/file path, sources `hooks/_lib.sh` for config/audit utilities, then exits 0 (allow) or 2 (deny). Hooks never crash the host tool — all internal errors exit 0.

**Key modules:**
- `hooks/_lib.sh` — shared library: YAML config loading (hand-parsed, no external tools), JSON I/O via `jq`, audit logging, state counters
- `hooks/pre-tool-use/guard-*.sh` — guardrails that block before execution (branch protection, destructive commands, file protection, commit hygiene, blast radius, uncommitted changes)
- `hooks/post-tool-use/` — automations after execution (checkpoint, format, lint, audit trail)
- `hooks/stop/` — session-end hooks (squash checkpoints, require tests, cost tracker)
- `templates/settings.hooks.json` — hook registration template for Claude Code
- `templates/claude.md.inject` — markdown block injected into project CLAUDE.md on install
- `hapai.defaults.yaml` — default config; users override with `hapai.yaml` in project root

**Config resolution:** project `hapai.yaml` → global `~/.hapai/hapai.yaml` → `hapai.defaults.yaml`

**State:** audit log at `~/.hapai/audit.jsonl` (append-only JSONL), per-hook counters at `~/.hapai/state/`.

## Conventions

- All scripts use `set -euo pipefail`
- Exit codes follow Claude Code hook API: `0` = allow, `2` = deny
- JSON output constructed via `jq -n` (safe against injection)
- User-facing messages go to stderr, structured output to stdout
- Hook timeouts: PreToolUse=7s, PostToolUse=5s, Stop=10s
- Each guardrail is one file, one concern, 50-100 LOC
- `fail_open: true` means warn but don't block; `false` means hard deny
