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

### Running a Single Test Group

Tests are structured by hook name with section headers. Filter output to a specific hook:

```bash
bash tests/run-tests.sh 2>&1 | grep -A 30 "guard-branch"
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

**Hook directory structure:**
- `hooks/_lib.sh` — shared library: YAML config loading (hand-parsed, no external tools), JSON I/O via `jq`, audit logging, state counters, blocklist, cooldown
- `hooks/pre-tool-use/guard-branch.sh` — blocks commits/pushes to protected branches (main, master)
- `hooks/pre-tool-use/guard-branch-rules.sh` — enforces branch naming: allowed prefixes, kebab-case description, must branch from protected base
- `hooks/pre-tool-use/guard-branch-taxonomy.sh` — validates taxonomy prefix on branch creation
- `hooks/pre-tool-use/guard-commit-msg.sh` — blocks AI co-authorship strings in commit messages
- `hooks/pre-tool-use/guard-destructive.sh` — blocks rm -rf, force-push, DROP TABLE, etc.
- `hooks/pre-tool-use/guard-files.sh` — blocks writes to .env, lockfiles, CI workflow files
- `hooks/pre-tool-use/guard-blast-radius.sh` — warns (fail-open) when commit touches too many files/packages
- `hooks/pre-tool-use/guard-uncommitted.sh` — warns (fail-open) on uncommitted changes before new operations
- `hooks/pre-tool-use/guard-git-workflow.sh` — enforces trunk-based workflow (blocks long-lived branches, non-FF merges); disabled by default (`guardrails.git_workflow.enabled: false`)
- `hooks/pre-tool-use/guard-pr-review.sh` — runs background AI review before push; opt-in (`guardrails.pr_review.enabled: false`)
- `hooks/pre-tool-use/flow-dispatcher.sh` — runs sequential hook chains defined in `hapai.yaml` under `flows`
- `hooks/post-tool-use/auto-checkpoint.sh`, `auto-format.sh`, `auto-lint.sh` — automations after Write/Edit
- `hooks/post-tool-use/audit-trail.sh`, `pr-review-trigger.sh` — audit logging and PR review initiation
- `hooks/stop/squash-checkpoints.sh`, `require-tests.sh`, `cost-tracker.sh` — session-end automations

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

- `hapai.defaults.yaml` — master config for all guardrails, automation, observability, and cloud settings
- Global override: `~/.hapai/hapai.yaml`
- Project override: `hapai.yaml` in project root

**Config resolution:** project `hapai.yaml` → `~/.hapai/hapai.yaml` → `hapai.defaults.yaml`

**`fail_open`:** `true` = warn but allow (e.g. blast_radius, uncommitted_changes); `false` = hard deny.

**Blocklist & cooldown:** Configured under `blocklist.enabled` and `cooldown.*`. Cooldown escalates a hook to fail-open after exceeding `threshold` denials in `window_minutes`, resetting after `cooldown_minutes`.

**Flows:** Sequential hook chains defined under `flows.<name>.steps[]`, each with a `hook:` path and `gate: block|warn|skip`. Enabled via `flows.enabled: true`. Dispatched by `hooks/pre-tool-use/flow-dispatcher.sh`.

**State storage:** Audit log at `~/.hapai/audit.jsonl` (append-only JSONL), per-hook counters at `~/.hapai/state/`.

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

## Development Workflows

### Adding a New Guardrail

1. Create `hooks/pre-tool-use/guard-{name}.sh` — source `_lib.sh`, call `read_input`, exit 0 or 2
2. Add config entry in `hapai.defaults.yaml` under `guardrails.{name}`
3. Test in isolation: `echo '...' | bash hooks/pre-tool-use/guard-{name}.sh`
4. Add assertions in `tests/run-tests.sh`
5. Run full test suite: `bash tests/run-tests.sh`

### Testing the CLI Installation

```bash
bash install.sh --global       # installs to ~/.hapai/
hapai validate
hapai status
hapai audit
```

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

## Key Documentation

- **`README.md`** — Project overview, guardrail reference table, quick start
- **`USAGE.md`** — Portuguese-language usage guide (installation, configuration, examples)
- **`CHANGELOG.md`** — Version history and release notes
- **`infra/gcp/SETUP.md`** — Cloud infrastructure setup guide
- **`infra/gcp/OIDC-SETUP.md`** — GitHub Actions OIDC Workload Identity configuration
