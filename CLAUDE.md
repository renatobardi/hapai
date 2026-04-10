# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is hapai

hapai is a deterministic guardrails system for AI coding assistants (Claude Code, Cursor, Copilot). It enforces security rules via shell-based hooks that intercept tool calls and block violations **before execution** — not probabilistic prompts that can be ignored. Pure Bash, only external dependency is `jq`.

The system combines:
- **Hook enforcement** — Shell scripts that run before/after tool execution
- **Svelte 5 Analytics Dashboard** — Real-time guardrail event visualization
- **Cloud integration** — BigQuery + Cloud Storage + GitHub Pages deployment
- **Multi-tool exporters** — Export guardrails to Cursor, Copilot, Windsurf, etc.

## Prerequisites

Before working on this codebase, ensure:
- **jq 1.6+** — Required for all hook scripts and validation. Install: `brew install jq`
- **Node.js + npm** — Required only for dashboard development (`infra/gcp/dashboard/`)
- **Bash 4+** — All scripts use `set -euo pipefail` and POSIX-compatible tools
- **Tested platforms** — macOS and Linux. CI runs on both via `ci.yml`. WSL supported via installer detection.

## Quick Commands

Common tasks when developing hapai:

```bash
# Run all tests (bash assertions, no framework)
bash tests/run-tests.sh

# Test a specific guardrail
bash tests/run-tests.sh 2>&1 | grep -A 30 "guard-branch"

# Test individual hook in isolation
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' | \
  bash hooks/pre-tool-use/guard-branch.sh

# Validate installation
hapai validate

# Check active hooks and audit counts
hapai status

# View recent audit log entries
hapai audit

# Dashboard development (local)
cd infra/gcp/dashboard && npm ci && npm run dev

# Dashboard production build
cd infra/gcp/dashboard && npm run build

# Test CLI installation locally
HAPAI_DEV=1 bash install.sh
```

### Testing Individual Hooks

Hooks read Claude Code's hook JSON format from stdin. The correct schema:

```bash
# PreToolUse — Bash command
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' | \
  bash hooks/pre-tool-use/guard-branch.sh
echo "Exit: $?"  # 0=allow, 2=deny

# PreToolUse — file write
echo '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":".env","content":"SECRET=1"}}' | \
  bash hooks/pre-tool-use/guard-files.sh
```

To test with a clean isolated state:

```bash
export HAPAI_HOME="$(mktemp -d)"
mkdir -p "$HAPAI_HOME/state"
cp hapai.defaults.yaml "$HAPAI_HOME/hapai.yaml"
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | \
  bash hooks/pre-tool-use/guard-destructive.sh
```

## Architecture

### Directory Structure

```
hapai/
├── bin/hapai                    # CLI entry point (command dispatcher)
├── hooks/                       # All guardrail scripts (pure Bash)
│   ├── _lib.sh                 # Shared library (YAML parsing, JSON I/O, audit, state)
│   ├── pre-tool-use/           # Block before Claude Code execution
│   │   ├── guard-*.sh          # Individual guardrails (branch, commit, files, etc.)
│   │   └── flow-dispatcher.sh  # Sequential hook chains from config
│   ├── post-tool-use/          # Run after Claude Code execution
│   │   ├── auto-*.sh           # Automations (format, lint, checkpoint)
│   │   └── audit-trail.sh      # Audit logging and PR review
│   └── stop/                   # Run at session end
│       └── *.sh                # Cleanup and cost tracking
├── install.sh                  # Universal installer (curl-safe)
├── tests/run-tests.sh          # All tests: bash assertions, no framework
├── hapai.defaults.yaml         # Master config (all guardrails + cloud settings)
├── infra/gcp/dashboard/        # Svelte 5 analytics app (separate npm project)
│   ├── src/                    # Svelte components, Firebase SDK integration
│   ├── package.json            # Node.js dependencies (Vite, Svelte, Chart.js)
│   └── .env                    # Firebase config (secrets)
├── infra/gcp/*.md              # GCP setup guides (SETUP.md, OIDC-SETUP.md)
├── templates/                  # Code generation templates
│   ├── settings.hooks.json     # Hook registration for Claude Code
│   └── claude.md.inject        # CLAUDE.md block injected on install
├── exporters/                  # Multi-tool guardrail exporters
│   └── export-*.sh             # Export for Cursor, Copilot, Windsurf
└── README.md, CHANGELOG.md     # Documentation and version history
```

**Two distinct runtimes:** Hooks are pure Bash (no npm dependencies); dashboard requires Node.js. They're independent — you can use hapai hooks without the dashboard.

### Hook System

**CLI** (`bin/hapai`) — Full-featured command center. Copies hooks to `~/.hapai/hooks/`, registers them in Claude Code's `~/.claude/settings.json`, and injects rules into CLAUDE.md.

**All CLI commands:**

| Command | Description |
|---|---|
| `install [--global\|--project]` | Install hooks globally or per-project |
| `uninstall [--global]` | Remove hooks and clean settings.json |
| `validate` | Check hooks, settings.json, hapai.yaml, jq version |
| `status` | Show active hooks, risk tier, audit counts |
| `audit` | Display recent audit.jsonl entries |
| `kill` | Emergency disable — renames all hooks to `.sh.disabled` |
| `revive` | Restore hooks after `kill` |
| `block <pattern> --type <type> --for <duration> --reason <msg>` | Add a TTL-based blocklist entry |
| `unblock <pattern> --type <type>` | Remove a blocklist entry |
| `blocklist` | Show all active (non-expired) blocklist entries |
| `list-hooks` | List all installed hooks |
| `sync` | Upload audit logs to Cloud Storage (GCP required) |
| `export [--all]` | Export guardrails to Cursor, Copilot, Windsurf formats |

**Hook lifecycle** — Claude Code triggers hooks via JSON on stdin. Each hook reads tool name/command/file path, sources `hooks/_lib.sh` for config/audit utilities, then exits 0 (allow) or 2 (deny). Hooks never crash the host tool — all internal errors exit 0 (fail-open trap).

### `_lib.sh` Key Functions

- `read_input()` / `get_field()` / `get_tool_name()` — parse hook JSON from stdin
- `deny()` / `warn()` / `allow()` — exit with structured JSON response
- `config_get(key, default)` — read nested YAML key (e.g. `"guardrails.branch_protection.enabled"`)
- `config_get_list(key)` — read YAML array (inline or block format)
- `state_get()` / `state_set()` / `state_increment()` — persistent counters in `~/.hapai/state/`
- `blocklist_add()` / `blocklist_check()` / `blocklist_clean()` — TTL-based pattern blocking
- `cooldown_active()` / `cooldown_record()` — after N denials in a window, escalate to fail-open
- `audit_log()` — appends JSONL entry to `~/.hapai/audit.jsonl`

### Environment Variables

- `HAPAI_HOME` (default: `$HOME/.hapai`) — root for state, config, and audit logs
- `CLAUDE_PROJECT_DIR` — set by Claude Code; used to find project-local `hapai.yaml`
- `HAPAI_AUDIT_LOG` — always `$HAPAI_HOME/audit.jsonl`

### Configuration

Configuration files are resolved in this order (first match wins):

1. **Project-local:** `hapai.yaml` in project root (when `CLAUDE_PROJECT_DIR` is set by Claude Code)
2. **User global:** `~/.hapai/hapai.yaml` (applies to all projects using user's hapai)
3. **Built-in defaults:** `hapai.defaults.yaml` (fallback, always available)

**Config structure:**

- `guardrails.{name}.enabled` — Enable/disable a specific guardrail
- `guardrails.{name}.fail_open` — `true` = warn but allow; `false` = hard deny
- `blocklist.enabled` — TTL-based pattern blocking system
- `cooldown.*` — After N denials in a window, escalate hook to fail-open (prevents annoyance)
- `flows.{name}.steps[]` — Sequential hook chains with `hook:` path and `gate: block|warn|skip`
- Cloud settings: `observability`, `cloud_storage`, `bigquery` — for GCP integration

**State storage:**

- `~/.hapai/audit.jsonl` — Append-only JSONL log of all hook executions (allow/deny/warn)
- `~/.hapai/state/` — Per-hook counters (used by cooldown and rate limiting)
- `~/.hapai/hapai.yaml` — User's global config overrides

**For hapai development:** Project config lives in `hapai.yaml` (checked in), not in `~/.hapai/`.

### Dashboard

**Location:** `infra/gcp/dashboard/` — Svelte 5 app that visualizes guardrail events from BigQuery.

**Tech stack:** Svelte 5, Vite 6, Firebase SDK (GitHub OAuth), Chart.js. No Tailwind — uses `app.css`.

**Routing:** Hash-based (`#/docs`, `#/config`, etc.) via `stores/route.js`. `App.svelte` is the auth gate and router. Key components: `Dashboard.svelte` (metrics), `HowItWorksPage.svelte` (docs), chart components (`HooksChart`, `TrendChart`, `DenialsTable`, etc.).

**Environment variables** (Vite, set in `infra/gcp/dashboard/.env`):
```
VITE_FIREBASE_API_KEY
VITE_FIREBASE_AUTH_DOMAIN
VITE_FIREBASE_PROJECT_ID
VITE_FIREBASE_APP_ID
VITE_BQ_PROXY_URL        # Cloud Functions proxy endpoint for BigQuery
```

**Build & deployment:**
- Local dev: `cd infra/gcp/dashboard && npm ci && npm run dev` (port 5173)
- Build: `npm run build` → outputs to `_site/` (base path: `/hapai/`)
- Deployment: automatic via `deploy-dashboard.yml` when `infra/gcp/dashboard/**` changes

**Setup prerequisites:** See `infra/gcp/SETUP.md` for Firebase project creation, OAuth provider setup, and GitHub Actions secrets configuration.

### Templates & Exporters

- `templates/settings.hooks.json` — hook registration template for Claude Code
- `templates/claude.md.inject` — markdown block injected into project CLAUDE.md on install (wrapped in `<!-- hapai:start -->...<!-- hapai:end -->`)
- `templates/guardrails-rules.md` — human-readable guardrails reference
- `exporters/export-*.sh` — exporters for Cursor, Copilot, Windsurf, Devin, etc.

## Claude Code Integration

### Hook Event Types & Exit Codes

- **PreToolUse** — Fires before Claude Code executes a tool (Bash, Write, Edit, etc.)
- **PostToolUse** — Fires after tool execution (automations: format, lint, checkpoint)
- **Stop** — Fires when session ends (cleanup, cost tracking)

Exit codes follow the Claude Code hook API:
- `0` — Allow execution
- `2` — Deny execution (show error to user)

All other exits are treated as `0` (fail-open trap in `_lib.sh` prevents hook crashes).

### Installation Modes

**Global installation** (`hapai install --global`):
- Hooks copied to `~/.hapai/hooks/`
- Settings registered in `~/.claude/settings.json`
- Applies to ALL projects using Claude Code on this machine
- Configuration: `~/.hapai/hapai.yaml` or built-in defaults

**Project installation** (`hapai install --project` or `cd project && hapai install`):
- Hooks copied to `.claude/hooks/hapai/`
- Settings registered in `.claude/settings.json` (project-local)
- Applies only to this project
- Configuration: `hapai.yaml` (checked into git) → `~/.hapai/hapai.yaml` → defaults

**For hapai development:** Install globally, then test using project-local overrides in `hapai.yaml`.

## Development Workflows

### Adding a New Guardrail

1. Create `hooks/pre-tool-use/guard-{name}.sh` — source `_lib.sh`, call `read_input`, exit 0 or 2
2. Add config entry in `hapai.defaults.yaml` under `guardrails.{name}`
3. Test in isolation: `echo '...' | bash hooks/pre-tool-use/guard-{name}.sh`
4. Add assertions in `tests/run-tests.sh`
5. Run full test suite: `bash tests/run-tests.sh`

### Testing the CLI Installation

When developing hapai itself, use **development mode** to test changes without permanently installing:

```bash
# Test installer logic without installing
HAPAI_DEV=1 bash install.sh

# This clones the installer but sources from the local ./bin/hapai instead of downloaded binary
```

**Working on the hapai repo:**

1. Make changes to hooks, CLI, or tests
2. Run tests: `bash tests/run-tests.sh`
3. Test CLI commands against local hooks: `./bin/hapai status`
4. For full end-to-end testing, install globally, then override with project config:
   ```bash
   bash install.sh --global     # installs to ~/.hapai/
   hapai validate
   hapai status
   hapai audit
   ```
5. Create a test project, install locally, and verify behavior

**Important:** When developing the guardrails system itself (not using it), commit to `docs/`, `feat/`, `fix/` branches, never to `main`. The hooks enforce this via `guard-branch.sh`.

### Cloud Setup (GCP/BigQuery)

See `infra/gcp/SETUP.md`. Enabled via `hapai sync` after GCP setup. Key steps: Firebase project, GitHub OAuth provider, Cloud Functions for BigQuery streaming, OIDC Workload Identity Federation.

## GitHub Actions Workflows

- **`ci.yml`** — Runs `bash tests/run-tests.sh` on push to main and all PRs (Ubuntu + macOS)
- **`deploy-dashboard.yml`** — Builds and deploys dashboard to GitHub Pages when `infra/gcp/dashboard/**` changes
- **`hapai-sync.yml`** — Syncs audit logs to Cloud Storage and triggers BigQuery ingestion (requires GCP setup)
- **`release.yml`** — Creates releases and publishes to Homebrew tap

## Conventions

- All scripts use `set -euo pipefail`
- Exit codes follow Claude Code hook API: `0` = allow, `2` = deny
- JSON output constructed via `jq -n` (safe against injection); strings always passed via `--arg`
- User-facing messages go to stderr, structured output to stdout
- Hook timeouts: PreToolUse=7s, PostToolUse=5s, Stop=10s
- Each guardrail is one file, one concern, 50-100 LOC
- Hooks must never crash — all internal errors exit 0 (fail-open via global ERR trap in `_lib.sh`)
- Bash portability: uses POSIX grep/sed; tested on Ubuntu + macOS in CI

