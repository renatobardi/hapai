# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is hapai

hapai is a deterministic guardrails system for AI coding assistants (Claude Code, Cursor, Copilot). It enforces security rules via shell-based hooks that intercept tool calls and block violations **before execution** — not probabilistic prompts that can be ignored. Pure Bash, only external dependency is `jq`.

The system combines:
- **Hook enforcement** — Shell scripts that run before/after tool execution
- **Svelte 5 Analytics Dashboard** — Real-time guardrail event visualization
- **Cloud integration** — BigQuery + Cloud Storage + GitHub Pages deployment
- **Multi-tool exporters** — Export guardrails to Cursor, Copilot, Windsurf, etc.

## Running Tests

```bash
bash tests/run-tests.sh
```

Tests are bash-based assertions in a single file. No test framework — just `assert_*` functions. CI runs on both macOS and Linux via `ci.yml`. Tests require `jq` to be installed.

### Testing Individual Hooks

Each hook can be tested in isolation by invoking it with mock JSON input:

```bash
# Example: test the branch protection guard
echo '{"tool":"Bash","command":"git commit...","file_path":"/path"}' | \
  bash hooks/pre-tool-use/guard-branch.sh
```

Hooks exit with code `0` (allow) or `2` (deny). Check the exit code to verify behavior.

## Architecture

### Hook System

**CLI** (`bin/hapai`) — install/uninstall/validate/status/audit commands. Copies hooks to `~/.hapai/hooks/`, registers them in Claude Code's `~/.claude/settings.json`, and injects rules into CLAUDE.md.

**Hook lifecycle** — Claude Code triggers hooks via JSON on stdin. Each hook reads tool name/command/file path, sources `hooks/_lib.sh` for config/audit utilities, then exits 0 (allow) or 2 (deny). Hooks never crash the host tool — all internal errors exit 0.

**Hook directory structure:**
- `hooks/_lib.sh` — shared library: YAML config loading (hand-parsed, no external tools), JSON I/O via `jq`, audit logging, state counters
- `hooks/pre-tool-use/guard-*.sh` — guardrails that block before execution (branch protection, destructive commands, file protection, commit hygiene, blast radius, uncommitted changes)
- `hooks/post-tool-use/` — automations after execution (checkpoint, format, lint, audit trail)
- `hooks/stop/` — session-end hooks (squash checkpoints, require tests, cost tracker)

### Configuration

- `hapai.defaults.yaml` — default config for all guardrails, automation, observability, and cloud settings
- Global override: `~/.hapai/hapai.yaml` — user's global config
- Project override: `hapai.yaml` in project root — per-project rules

**Config resolution:** project `hapai.yaml` → global `~/.hapai/hapai.yaml` → `hapai.defaults.yaml`

**State storage:** audit log at `~/.hapai/audit.jsonl` (append-only JSONL), per-hook counters at `~/.hapai/state/`.

### Dashboard

**Location:** `infra/gcp/dashboard/` — Svelte 5 app that visualizes guardrail events from BigQuery.

**Tech stack:** Svelte 5, Vite, Firebase SDK, Chart.js.

**Build & deployment:**
- Local dev: `cd infra/gcp/dashboard && npm run dev`
- Build: `npm run build` → outputs to `_site/`
- Deployment: automatic via `deploy-dashboard.yml` when `infra/gcp/dashboard/**` changes
- Live at: `https://{owner}.github.io/{repo}/` after GitHub Pages setup

**Setup prerequisites:** See `infra/gcp/SETUP.md` for Firebase project creation, OAuth provider setup, and GitHub Actions secrets configuration.

### Templates & Exporters

- `templates/settings.hooks.json` — hook registration template for Claude Code
- `templates/claude.md.inject` — markdown block injected into project CLAUDE.md on install
- `templates/guardrails-rules.md` — human-readable guardrails reference
- `exporters/export-*.sh` — exporters for Cursor, Copilot, Windsurf, Devin, etc.

## Development Workflows

### Running the Dashboard Locally

```bash
cd infra/gcp/dashboard
npm ci
npm run dev
```

Vite dev server runs on `http://localhost:5173`. Requires Firebase project setup with valid `.env` credentials.

### Building the Dashboard

```bash
cd infra/gcp/dashboard
npm ci
npm run build
```

Output in `_site/`. The `deploy-dashboard.yml` workflow automatically builds and deploys to GitHub Pages when you push to main.

### Testing the CLI Installation

```bash
# Install globally (installs to ~/.hapai/)
bash install.sh --global

# Or per-project
cd your-project && bash /path/to/hapai/install.sh --project

# Verify installation
hapai validate

# Check status
hapai status

# View recent audit log
hapai audit
```

### Adding a New Guardrail

1. Create a new file in `hooks/pre-tool-use/guard-{name}.sh`
2. Use the guard template pattern (source `_lib.sh`, read JSON input, exit 0 or 2)
3. Add config entry in `hapai.defaults.yaml` under `guardrails.{name}`
4. Test: `echo '...' | bash hooks/pre-tool-use/guard-{name}.sh`
5. Add assertions in `tests/run-tests.sh`
6. Run full test suite: `bash tests/run-tests.sh`

### Cloud Setup (GCP/BigQuery)

See `infra/gcp/SETUP.md` for complete cloud infrastructure setup:
- Firebase project creation
- GitHub OAuth provider configuration
- Cloud Functions for BigQuery streaming
- OIDC Workload Identity Federation for GitHub Actions
- Cloud Storage bucket for audit log syncing

Enabled via `hapai sync` command after GCP setup is complete.

## GitHub Actions Workflows

- **`ci.yml`** — Runs `bash tests/run-tests.sh` on push to main and all PRs (both Ubuntu and macOS)
- **`deploy-dashboard.yml`** — Builds and deploys dashboard to GitHub Pages when `infra/gcp/dashboard/**` changes
- **`hapai-sync.yml`** — Syncs audit logs to Cloud Storage and triggers BigQuery ingestion (requires GCP setup)
- **`release.yml`** — Creates releases and publishes to Homebrew tap

## Conventions

- All scripts use `set -euo pipefail`
- Exit codes follow Claude Code hook API: `0` = allow, `2` = deny
- JSON output constructed via `jq -n` (safe against injection)
- User-facing messages go to stderr, structured output to stdout
- Hook timeouts: PreToolUse=7s, PostToolUse=5s, Stop=10s
- Each guardrail is one file, one concern, 50-100 LOC
- `fail_open: true` means warn but don't block; `false` means hard deny

## Key Documentation

- **`README.md`** — Project overview, guardrail reference table, quick start
- **`USAGE.md`** — Portuguese-language usage guide (installation, configuration, examples)
- **`CHANGELOG.md`** — Version history and release notes
- **`infra/gcp/SETUP.md`** — Cloud infrastructure setup guide
- **`infra/gcp/OIDC-SETUP.md`** — GitHub Actions OIDC Workload Identity configuration
