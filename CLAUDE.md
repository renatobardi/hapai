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
- **Node.js 20+ + npm** — Required only for dashboard development (`infra/gcp/dashboard/`)
- **Bash 4+** — All scripts use `set -euo pipefail` and POSIX-compatible tools
- **Git** — Version control and release tagging
- **Tested platforms** — macOS and Linux. CI runs on both via `ci.yml`. WSL supported via installer detection.

## Development Environment Setup

**Complete setup for contributing:**

```bash
# 1. Clone the repository
git clone https://github.com/renatobardi/hapai.git
cd hapai

# 2. Verify prerequisites
jq --version      # Should be 1.6+
bash --version    # Should be 4+
node --version    # Should be 20+ (only if developing dashboard)

# 3. Install for development with hooks enabled
HAPAI_DEV=1 bash install.sh

# 4. Validate installation
hapai validate

# 5. Run full test suite to verify everything works
bash tests/run-tests.sh

# 6. For dashboard development, install Node dependencies
cd infra/gcp/dashboard && npm ci && cd ../..

# You're ready to develop!
```

**Development setup notes:**
- `HAPAI_DEV=1` installs hooks to `~/.hapai/hooks/` and registers them in `~/.claude/settings.json`
- Project-local `hapai.yaml` overrides user-global `~/.hapai/hapai.yaml` — useful for testing
- All hook changes take effect immediately; no reinstall needed
- Dashboard requires `.env` file with Firebase credentials (see Dashboard section)

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
│   ├── _pr-review-agent.sh     # Background PR reviewer (claude CLI, Haiku model)
│   ├── _pr-fix-agent.sh        # Optional auto-fixer (Sonnet model)
│   ├── pre-tool-use/           # Block before Claude Code execution
│   │   ├── guard-*.sh          # Individual guardrails (branch, commit, files, etc.)
│   │   └── flow-dispatcher.sh  # Sequential hook chains from config
│   ├── post-tool-use/          # Run after Claude Code execution
│   │   ├── auto-*.sh           # Automations (format, lint, checkpoint)
│   │   └── audit-trail.sh      # Audit logging and PR review
│   ├── stop/                   # Run at session end (cleanup, cost tracking)
│   ├── session-start/          # Load context, scan TODOs/issues on session init
│   ├── user-prompt-submit/     # Warn on production keywords before any tool runs
│   ├── pre-compact/            # Backup transcript before context compaction
│   ├── notification/           # Sound alerts on guardrail events
│   ├── permission-request/     # Auto-allow read-only operations
│   └── git/                    # post-commit hook for non-Claude tools (hapai sync)
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
| `install --git-hooks` | Install post-commit hook for non-Claude tools (fires `hapai sync`) |
| `uninstall --git-hooks` | Remove post-commit hook |
| `version` | Show installed hapai version |

**Hook lifecycle** — Claude Code triggers hooks via JSON on stdin. Each hook reads tool name/command/file path, sources `hooks/_lib.sh` for config/audit utilities, then exits 0 (allow) or 2 (deny). Hooks never crash the host tool — all internal errors exit 0 (fail-open trap).

### `_lib.sh` Key Functions

- `read_input()` / `get_field()` / `get_tool_name()` — parse hook JSON from stdin
- `deny()` / `warn()` / `allow()` — exit with structured JSON response
- `config_get(key, default)` — read nested YAML key (e.g. `"guardrails.branch_protection.enabled"`)
- `config_get_list(key)` — read YAML array (inline or block format)
- `state_get()` / `state_set()` / `state_increment()` — persistent counters in `~/.hapai/state/`
- `blocklist_add()` / `blocklist_check()` / `blocklist_clean()` — TTL-based pattern blocking
- `cooldown_active()` / `cooldown_record()` — after N denials in a window, escalate to fail-open
- `audit_log()` — appends JSONL entry to `~/.hapai/audit.jsonl` (includes `event_id` and optional `context_json`)
- `_audit_event_id()` — generates unique event ID: `<epoch_ms>-<hook>-<rand4hex>` (dedup key for BigQuery MERGE)
- `_is_flow_managed()` — returns true if `HAPAI_FLOW_EXECUTOR=1` (prevents double-logging when invoked via flow-dispatcher)

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
- `risk_tier` — Global severity level (`low | medium | high | critical`); controls default deny vs. warn behavior
- `blocklist.enabled` — TTL-based pattern blocking system
- `cooldown.*` — After N denials in a window, escalate hook to fail-open (prevents annoyance)
- `flows.{name}.steps[]` — Sequential hook chains; each step has `hook:` path, `gate: block|warn|skip`, and optional `match:` pattern
  - `gate: block` — a denial from this step stops the chain; `gate: warn` — logs but continues; `gate: skip` — always continues
  - `match:` syntax: `"Bash(git commit*)"` (tool + glob on input) or bare tool names like `"Write|Edit|MultiEdit"`
- Cloud settings: `observability`, `cloud_storage`, `bigquery` — for GCP integration

**PR review config** (`guardrails.pr_review.*`):
- `enabled` — Run background code review after `gh pr create` / `git push -u`
- `model` — Claude model for reviews (default: `claude-haiku-4-5-20251001`)
- `review_timeout_seconds` — Abort review after N seconds (default: 300)
- `max_diff_chars` — Skip review if diff exceeds this (default: 8000; token cost guard)
- `base_branch` — Override base branch; empty = auto-detect
- `auto_fix.enabled` — Automatically fix issues found by reviewer (model: Sonnet, off by default)

**Branch taxonomy config** (`guardrails.branch_taxonomy.*`):
- `allowed_prefixes` — List of valid branch prefixes (e.g. `feat/, fix/, chore/`)
- `require_description` — Enforce `prefix/description` format (not just `prefix/`)

**State storage:**

- `~/.hapai/audit.jsonl` — Append-only JSONL log of all hook executions (allow/deny/warn); each entry has `event_id` + optional `context` object
- `~/.hapai/state/` — Per-hook counters (used by cooldown and rate limiting)
- `~/.hapai/state/sync_cursor` — Line count from last `hapai sync` (enables incremental delta sync)
- `~/.hapai/hapai.yaml` — User's global config overrides

**For hapai development:** Project config lives in `hapai.yaml` (checked in), not in `~/.hapai/`.

### Dashboard

**Location:** `infra/gcp/dashboard/` — Svelte 5 app that visualizes guardrail events from BigQuery.

**Tech stack:** Svelte 5 (runes syntax: `$state()`, `$derived()`, `$effect()`), Vite 6, Firebase SDK (GitHub OAuth). No Tailwind — uses `app.css` with 22+ CSS custom properties (design tokens).

**Routing:** Hash-based (`#/docs`, `#/config`, etc.) via `stores/route.js`. `App.svelte` is the router. Unauthenticated visitors see `LandingPage.svelte`; authenticated users see `Dashboard.svelte`.

**Store layer** (`src/stores/`):
- `auth.js` — `authStore` with shape `{ user, idToken, loading }`; wraps Firebase `onAuthStateChanged`
- `dashboard.js` — `dashboardStore` with shape `{ loading, error, period, statsComparison, timeline, projectHealth, hooks, denialReasons, contextBreakdown, denials, denialsOffset, denialsHasMore, drilldownDetail, drilldownDetailLoading, drilldownDetailError }`
  - `loadDashboard(idToken, period)` — fetches all 7 queries in parallel via `Promise.all`
  - `setPeriod(idToken, period)` — reloads all data for the selected period (7/14/30 days)
  - `loadMoreDenials(idToken, period)` — server-side pagination for events table
  - `loadDrilldownDetail(type, name, idToken, period)` — fetches `hook_detail` or `tool_detail` for drill-down
- `i18n.js` — `locale` (writable), `setLocale()`, and `t` (derived store returning a translation function); browser language auto-detected, persisted to localStorage
- `route.js` — `route` writable store; updated by `hashchange` events; `navigate(hash)` for programmatic routing

**i18n:** Three locales in `src/lib/locales/` (`en.js`, `pt-BR.js`, `es-ES.js`) — JavaScript modules with `export default {}`. Translation keys are dot-separated (e.g. `header.nav.docs`). The `t` store is a derived store — use `$t('key')` in components. Language toggle is in `Header.svelte`. In Svelte template `{...}` blocks, literal curly braces in strings must be escaped as `&#123;` / `&#125;` to avoid parse errors.

**Key components** (`src/`):
- `App.svelte` — router shell
- `LandingPage.svelte` — unauthenticated landing page (hero, problem, solution, guardrails, ecosystem, quick start)
- `Dashboard.svelte` — tabbed dashboard (Overview, Projects, Guardrails, Events) with `_loaded` flag to prevent race condition between `onMount` and `$effect`
- `Header.svelte` — nav + GitHub sign-in/out + language toggle (EN/PT/ES)
- `HowItWorksPage.svelte` — docs page (`#/docs`) with scroll-spy sidebar
- KPI & overview: `KpiBar`, `StatCard` (with sparklines), `TimelineChart`
- Analytics: `ProjectHealth`, `DenialReasons`, `GuardrailGlossary`, `HooksChart`, `Hotspots`
- Events: `DenialsTable` (server-side pagination), `DrillDown` (L2 inline panel), `EventDetail` (L3 full-screen drawer)
- Shared UI: `Button`, `Card`, `Badge`, `EmptyState`, `LoadingState`, `Logo`

**API layer** (`src/lib/`):
- `firebase.js` — exports `auth`, `signIn()`, `signOut()`, `onAuthStateChanged` (GitHub OAuth provider)
- `api.js` — `queryBQ(queryName, idToken, params)` POSTs to `VITE_BQ_PROXY_URL` with Bearer token; 30s timeout via `AbortController`; per-status error messages (401/403/404); SonarQube-compliant exception handling

**Environment variables** (Vite, set in `infra/gcp/dashboard/.env`):
```
VITE_FIREBASE_API_KEY
VITE_FIREBASE_AUTH_DOMAIN
VITE_FIREBASE_PROJECT_ID
VITE_FIREBASE_APP_ID
VITE_BQ_PROXY_URL        # HTTP Cloud Function endpoint (hapai-bq-query)
```

**Build & deployment:**
- Local dev: `cd infra/gcp/dashboard && npm ci && npm run dev` (port 5173)
- Build: `npm run build` → outputs to `_site/` (base path: `/hapai/`)
- Deployment: automatic via `deploy-dashboard.yml` when `infra/gcp/dashboard/**` changes

**Setup prerequisites:** See `infra/gcp/SETUP.md` for Firebase project creation, OAuth provider setup, and GitHub Actions secrets configuration.

### Templates & Exporters

**Templates** (`templates/`):
- `settings.hooks.json` — Hook registration template for Claude Code (JSON with hook paths, conditions, gates)
- `guardrails-rules.md` — Guardrails markdown documentation (used by exporters)
- `claude.md.inject` — CLAUDE.md block injected on `hapai install` (contains guardrails rules)

**Exporters** (`exporters/`) — Convert hapai guardrails to other AI assistant formats:

| Exporter | Target | Output | Usage |
|----------|--------|--------|-------|
| `export-cursor.sh` | Cursor IDE | `.cursor/rules/hapai.mdc` | Exports as Cursor rules (MDC format) |
| `export-copilot.sh` | GitHub Copilot | `.github/copilot-instructions.md` | Exports as Copilot instructions |
| `export-windsurf.sh` | Windsurf | `.windsurf/rules.md` | Exports as Windsurf rules |
| `export-devin.sh` | Devin | `.devin/rules.md` | Exports as Devin rules |
| `export-trae.sh` | Trae | `.trae/rules.md` | Exports as Trae rules |
| `export-antigravity.sh` | Antigravity | `.antigravity/rules.md` | Exports as Antigravity rules |
| `export-universal.sh` | All formats | Multiple files | Runs all exporters |

**Using exporters:**
```bash
# Export to current tool
cd your-project && bash ~/hapai/exporters/export-cursor.sh

# Export to all supported tools
cd your-project && bash ~/hapai/exporters/export-universal.sh

# The exporter reads hapai config and guardrails from:
# - hapai.defaults.yaml (built-in)
# - ~/.hapai/hapai.yaml (user global)
# - hapai.yaml (project local)
```

**Developing a new exporter:**
1. Create `exporters/export-{tool}.sh` with shebang + `set -euo pipefail`
2. Read guardrails from `templates/guardrails-rules.md` or `hapai.defaults.yaml`
3. Generate target tool's rule format (MDC, markdown, etc.)
4. Write to standard location (`.{tool}/rules.*`)
5. Output filename as last line for confirmation
6. Add to `export-universal.sh` call list

## Cloud Functions (Python)

**Location:** `infra/gcp/functions/main.py` — Two Cloud Functions in a single module.

### `load_audit_from_gcs` (Storage Trigger)

**Trigger:** Gen2 CloudEvent (`google.cloud.storage.object.v1.finalized`) on `hapai-audit-*` buckets.

**Key responsibilities:**
- Parse JSONL audit logs from `~/.hapai/audit.jsonl` (uploaded by `hapai sync` — incremental, cursor-based)
- Validate identifiers and bucket names using regex patterns
- Batch-level Python dedup before BigQuery write
- Load events into BigQuery `hapai_dataset.events` table via `MERGE WHEN NOT MATCHED INSERT` keyed on `event_id`
- Fallback to streaming insert via `_merge_rows_by_event_id()` if MERGE job fails
- Handle legacy rows without `event_id`

### `hapai_bq_query` (HTTP Trigger)

**Trigger:** HTTP POST with Firebase Bearer token.

**Key responsibilities:**
- Dispatches to 10+ query functions based on `query_name` parameter
- All queries use dedup CTE: `ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY ts DESC)`
- Parameterized via `bigquery.ScalarQueryParameter` (injection-safe)
- Input validation: `_validate_period()`, `_validate_safe_string()`, `_validate_limit()`, `_validate_offset()`
- CORS headers for dashboard cross-origin requests

**Available queries:**
| Query Name | Description |
|---|---|
| `stats_comparison` | Current vs previous period KPIs (denials, warnings, allows, rates) |
| `timeline` | Daily deny/warn counts for chart |
| `hooks` | Top guards by denial count |
| `tools` | Top tools triggering guards |
| `projects` | Per-project event counts |
| `denials` | Paginated event feed (`limit`/`offset`) |
| `project_health` | Per-project deny rate, top guard, health score |
| `denial_reasons` | Aggregated denial reasons ranked by frequency |
| `context_breakdown` | File categories, risk tiers, branches from context RECORD |
| `hook_detail` | Drill-down: mini-timeline + breakdown + recent events per guard |
| `tool_detail` | Drill-down: mini-timeline + breakdown + recent events per tool |

### Schema

BigQuery table `hapai_dataset.events` — 8 top-level fields + 22-field `context` RECORD:

**Top-level fields:**
- `event_id` (STRING) — Unique event identifier (dedup key): `<epoch_ms>-<hook>-<rand4hex>`
- `ts` (TIMESTAMP) — UTC timestamp of event
- `event` (STRING) — Event type: `allow`, `deny`, `warn`
- `hook` (STRING) — Hook name (e.g., `guard-branch`, `guard-commit-hygiene`)
- `tool` (STRING) — Tool triggering hook (Bash, Write, Edit, etc.)
- `result` (STRING) — `0` (allowed), `2` (denied), or reason if `warn`
- `reason` (STRING) — Explanation for result
- `project` (STRING) — Project name (from `CLAUDE_PROJECT_DIR` or `git config user.name`)

**Context RECORD fields (optional, populated by hook context_json):**
- Git operations: `git_op`, `target_branch`, `bypass_method`
- Protection metadata: `protection_type`, `enforcement_method`, `protection_source`
- File details: `filename`, `file_category`, `file_fullpath`, `was_symlink`
- Blast radius: `files_staged_count`, `packages_touched_count`, `max_files_threshold`, `max_packages_threshold`, `packages_list`
- Rule matching: `matched_pattern`, `forbidden_pattern`, `pattern_source`
- Risk assessment: `risk_category`, `command_preview`, `commit_msg_length`
- Escalation: `was_cooldown_escalation`, `enforcement`

**Setup & deployment:**

Deployed via Cloud Functions console (Gen2 runtime, Python 3.12):

```bash
# Deploy load_audit_from_gcs (Storage trigger)
gcloud functions deploy load_audit_from_gcs \
  --gen2 \
  --runtime python312 \
  --trigger-resource hapai-audit-dev \
  --trigger-event google.cloud.storage.object.v1.finalized \
  --entry-point load_audit_from_gcs \
  --source infra/gcp/functions

# Deploy hapai_bq_query (HTTP trigger)
gcloud functions deploy hapai_bq_query \
  --gen2 \
  --runtime python312 \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point hapai_bq_query \
  --source infra/gcp/functions
```

See `infra/gcp/SETUP.md` for full GCP infrastructure setup (BigQuery datasets, Cloud Storage buckets, IAM roles).

## Developer Workflows

### Adding a New Guardrail

1. **Create the hook script** in `hooks/pre-tool-use/guard-{name}.sh`
   - Source `hooks/_lib.sh` for utilities (`deny()`, `allow()`, `warn()`, `config_get()`, `audit_log()`)
   - Read JSON input via `read_input()` and `get_field()`
   - Exit 0 to allow, 2 to deny
   - Add config key to `hapai.defaults.yaml`
   - Example structure:
     ```bash
     #!/usr/bin/env bash
     source "${BASH_SOURCE%/*}/_lib.sh"
     
     read_input
     TOOL=$(get_tool_name)
     
     # Custom logic here...
     
     if [[ some_violation ]]; then
       deny "Reason for denial" "{}context_json"
     else
       allow
     fi
     ```

2. **Register in settings.json template:**
   - Update `templates/settings.hooks.json` with the new hook under `hooks` array
   - Specify `if:` condition to match relevant tool calls
   - Set `gate: block` for hard deny, `gate: warn` for soft warn

3. **Add tests** to `tests/run-tests.sh`:
   - Test both allow and deny cases
   - Test with different config values (`fail_open: true/false`)
   - Use isolated `HAPAI_HOME` for each test group

4. **Document:**
   - Update README.md guardrails table with new guard
   - Add description to CLAUDE.md Architecture section
   - Update CHANGELOG.md with new feature

### Modifying Configuration

**Project-local settings** (`hapai.yaml`):
- Checked into repo; overrides global defaults
- Use for team-wide policies (required branch prefixes, protected branches, etc.)
- Syntax: YAML with nested keys like `guardrails.guard_name.enabled`

**User-global settings** (`~/.hapai/hapai.yaml`):
- Per-user overrides; never committed
- Takes precedence over project config; used for local testing

**Defaults** (`hapai.defaults.yaml`):
- Built-in fallback; master source of truth for all options
- Modifications here require tests and release notes

### Testing During Development

**Run all tests:**
```bash
bash tests/run-tests.sh
```

**Test a single hook:**
```bash
# Pre-compile your hook input JSON
HOOK_INPUT='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
echo "$HOOK_INPUT" | bash hooks/pre-tool-use/guard-branch.sh
echo "Exit code: $?"
```

**Test with custom config:**
```bash
export HAPAI_HOME="$(mktemp -d)"
mkdir -p "$HAPAI_HOME/state"
cp hapai.defaults.yaml "$HAPAI_HOME/hapai.yaml"
# Edit $HAPAI_HOME/hapai.yaml as needed
echo "$HOOK_INPUT" | bash hooks/pre-tool-use/guard-branch.sh
```

**Test flow-dispatcher chains:**
```bash
# Test sequential hook flows with match patterns
HOOK_INPUT='{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit"}}'
echo "$HOOK_INPUT" | bash hooks/pre-tool-use/flow-dispatcher.sh
```

**Test cooldown escalation:**
```bash
# Simulate N rapid denials to test cooldown escalation
export HAPAI_HOME="$(mktemp -d)"
mkdir -p "$HAPAI_HOME/state"
for i in {1..5}; do
  echo "$HOOK_INPUT" | bash hooks/pre-tool-use/guard-branch.sh
done
# After threshold, subsequent denials should escalate to fail-open
```

**Test audit logging and dedup:**
```bash
# Verify event_id uniqueness and JSONL format
cat ~/.hapai/audit.jsonl | jq '.event_id' | sort | uniq -d
# Should be empty (no duplicate event IDs)
```

**Watch tests during development:**
```bash
while inotifywait -e modify hooks/ tests/; do bash tests/run-tests.sh; done
```

**Run tests on multiple platforms:**
```bash
# CI automatically runs on Ubuntu + macOS via .github/workflows/ci.yml
# To test locally on WSL or different OS:
bash tests/run-tests.sh 2>&1 | tail -20  # Show summary
```

## Dashboard Local Development

**Environment setup:**
```bash
cd infra/gcp/dashboard
npm ci  # Install dependencies
```

**Create `.env` file:**
```
VITE_FIREBASE_API_KEY=xxx
VITE_FIREBASE_AUTH_DOMAIN=xxx
VITE_FIREBASE_PROJECT_ID=xxx
VITE_FIREBASE_APP_ID=xxx
VITE_BQ_PROXY_URL=https://your-cloud-functions-url
```

Get these values from your Firebase project (`infra/gcp/SETUP.md`).

**Local dev server:**
```bash
npm run dev  # Runs on http://localhost:5173
```

Svelte 5 uses runes syntax (`$state()`, `$derived()`, `$effect()`) — see components in `src/` for patterns.

**Important:** Svelte templates with literal `{...}` in strings must escape as `&#123;...&#125;` to avoid parse errors (see `src/lib/locales/` for examples).

**Vite configuration** (`vite.config.js`):
- Base path: `/hapai/` (for GitHub Pages deployment at `renatobardi.github.io/hapai`)
- Svelte plugin enabled with hot module reload
- SvelteKit-style routing via hash-based navigation
- CORS proxy headers for BigQuery API calls
- Output directory: `_site/` (standard for GitHub Pages)

**Build production:**
```bash
npm run build  # Outputs to _site/ with base path /hapai/
npm run preview  # Preview production build locally on http://localhost:4173
```

**i18n system:**
- Three locales in `src/lib/locales/`: `en.js`, `pt-BR.js`, `es-ES.js`
- Translation function: `$t('key.nested.path')`
- Browser language auto-detection, persisted to localStorage
- Language toggle in `Header.svelte` switches locale and reloads data
- **Important:** Literal `{...}` in Svelte templates must be escaped as `&#123;...&#125;` to avoid parse errors

## PR Review Agents

hapai includes optional background agents for automated code review and auto-fix:

### PR Review Agent (`_pr-review-agent.sh`)

**Trigger:** Runs after `gh pr create` or `git push -u` (via `post-tool-use/audit-trail.sh` when PR is detected).

**Behavior:**
- Fetches the PR's base branch and diff
- Invokes Claude (Haiku model by default) to review the code
- Checks diff size (`max_diff_chars` guard, default 8000)
- Aborts if review timeout exceeded (`review_timeout_seconds`, default 300s)
- Parses review markdown to extract issues with severity levels
- Logs findings back to stdout and audit trail

**Configuration** (`hapai.defaults.yaml`):
```yaml
guardrails:
  pr_review:
    enabled: true
    model: claude-haiku-4-5-20251001  # Change to Sonnet/Opus for complex reviews
    review_timeout_seconds: 300
    max_diff_chars: 8000  # Skip review if diff is huge
    base_branch: ""       # Auto-detect; override if needed
    auto_fix:
      enabled: false      # Set true to auto-fix found issues
```

**Requirements:**
- `claude` CLI installed and authenticated (`claude login`)
- Git repo with a tracked remote (for PR detection)
- Models must be available to authenticated user

### PR Auto-Fix Agent (`_pr-fix-agent.sh`)

**Trigger:** Runs after PR review if `pr_review.auto_fix.enabled: true`.

**Behavior:**
- Takes PR review findings and executes fixes
- Creates commits with bot-style messages (`[auto-fix] ...`)
- Pushes fixes back to the PR branch
- Currently uses Sonnet model (requires higher tier)

**Configuration:**
```yaml
guardrails:
  pr_review:
    auto_fix:
      enabled: false      # Disabled by default
      # Uses Sonnet model — enable carefully to avoid token bloat
```

**Limitations:**
- Only runs if PR review found actionable issues
- Skips safety-critical fixes (e.g., security issues — those are reviewed manually)
- Respects file protection guards — won't auto-fix protected files

## Common Tasks

### Debugging Hook Execution

1. **Check audit logs:**
   ```bash
   hapai audit
   ```
   Shows recent allow/deny events with timestamps and reasons.

2. **Review hook registration:**
   ```bash
   hapai list-hooks
   ```
   Shows which hooks are installed and active.

3. **Inspect hook state:**
   ```bash
   cat ~/.hapai/state/*
   ```
   View cooldown counters and rate-limit state.

4. **Test configuration loading:**
   ```bash
   HAPAI_HOME=/tmp/test_hapai bash -c '
     source hooks/_lib.sh
     config_get "guardrails.branch_protection.enabled"
   '
   ```

### Working with Branches Under Guardrails

- **Always use taxonomy prefixes** (feat/, fix/, chore/, docs/, refactor/, test/, perf/, style/, ci/, build/, release/, hotfix/)
- **Create feature branches from main:**
  ```bash
  git checkout main && git pull
  git checkout -b feat/my-feature
  ```
- **Never commit to protected branches** (main, master) — guard-branch.sh will block
- **Squash or rebase before PR** if needed, but avoid touching many files per commit

### Troubleshooting Hook Failures

**Hook fails silently or allows when it should deny:**
```bash
# 1. Check if hook is installed and executable
hapai list-hooks | grep guard-name

# 2. Check if guard is enabled in config
hapai status

# 3. Manually test the hook with isolated state
export HAPAI_HOME="$(mktemp -d)"
mkdir -p "$HAPAI_HOME/state"
cp hapai.defaults.yaml "$HAPAI_HOME/hapai.yaml"
HOOK_INPUT='...' bash hooks/pre-tool-use/guard-name.sh
echo "Exit: $?"  # 0=allow, 2=deny
```

**Hook is denying valid operations:**
```bash
# Check audit log for recent denials
hapai audit | tail -20

# Review the specific denial reason
hapai audit | jq '.[] | select(.hook == "guard-name")'

# Adjust config (project-local takes precedence):
cat hapai.yaml | grep -A 5 guard-name
# Set fail_open: true temporarily to see what's being caught
```

**Flow-dispatcher chain issues:**
```bash
# Test individual steps of a flow
FLOW_NAME="my-flow" bash -c '
  source hooks/_lib.sh
  config_get "flows.${FLOW_NAME}.steps[0].hook"
'

# Check if flow is being executed
grep "HAPAI_FLOW_EXECUTOR" ~/.hapai/audit.jsonl | tail -5
```

**Permission/cooldown escalation:**
```bash
# After N rapid denials, hooks escalate to fail-open
# Check current cooldown state
cat ~/.hapai/state/* | jq . 2>/dev/null

# Reset cooldown if needed (careful — this is manual override)
rm ~/.hapai/state/cooldown_* 2>/dev/null
```

### Syncing Audit Logs to GCP

```bash
hapai sync  # Upload ~/.hapai/audit.jsonl to Cloud Storage
```

Requires GCP credentials and `GOOGLE_APPLICATION_CREDENTIALS` set. See `infra/gcp/SETUP.md`.

## Release Workflow

hapai follows semantic versioning (v1.2.3) with automated releases via GitHub Actions.

### Creating a Release

**1. Tag a new release locally:**
```bash
bash scripts/tag-release.sh 1.8.0
```

This script:
- Validates semver format (X.Y.Z)
- Checks version consistency between `bin/hapai` and `hooks/_lib.sh`
- Creates git tag `v1.8.0` with annotated message
- Does NOT push — you control when it goes live

**2. Review and push:**
```bash
# Verify the tag was created
git tag -l v1.8.0

# Push the tag to trigger release workflow
git push origin main
git push origin v1.8.0
```

**3. GitHub Actions release.yml takes over:**
- Runs full test suite (`bash tests/run-tests.sh`)
- Builds universal tarballs (same binary for macOS/Linux — pure Bash)
- Computes SHA256 checksums
- Creates GitHub Release with install instructions
- Updates Homebrew formula automatically (requires `HOMEBREW_TAP_TOKEN` secret)

**Release artifacts:**
- `hapai-v1.8.0.tar.gz` — Universal tarball
- `hapai-v1.8.0-darwin.tar.gz` — Darwin label (Homebrew)
- `hapai-v1.8.0-linux.tar.gz` — Linux label (Homebrew)
- `checksums.txt` — SHA256 hashes for verification

**After release:**
Users can install via:
```bash
# Homebrew (automatic update via scripts/update-brew-formula.sh)
brew tap renatobardi/hapai
brew install hapai

# Direct curl install (works for any version)
curl -fsSL https://raw.githubusercontent.com/renatobardi/hapai/v1.8.0/install.sh | bash

# Manual download from GitHub Releases page
```

### Homebrew Integration

`scripts/update-brew-formula.sh` is called by release.yml to update the Homebrew tap. It:
- Clones `renatobardi/homebrew-hapai` tap using `HOMEBREW_TAP_TOKEN`
- Generates `Formula/hapai.rb` with correct version + SHA256
- Commits and pushes to tap repo
- Declares `jq` as a runtime dependency

Requirements:
- `HOMEBREW_TAP_TOKEN` set in GitHub Actions secrets (personal access token with repo write)
- Homebrew tap repo must exist at `github.com/renatobardi/homebrew-hapai`

## Resources

### Documentation Structure

| File | Purpose | Language |
|------|---------|----------|
| **README.md** | Feature overview, quick start, guardrail table | English |
| **USAGE.md** | Complete setup & configuration guide | Portuguese (pt-BR) |
| **CONTRIBUTING.md** | Contribution workflow & philosophy | English |
| **CHANGELOG.md** | Release notes and version history | English |
| **CLAUDE.md** (this file) | Codebase architecture for developers | English |
| **infra/gcp/SETUP.md** | GCP infrastructure setup (BigQuery, Functions, Storage) | English |
| **infra/gcp/OIDC-SETUP.md** | GitHub OAuth configuration for dashboard | English |
| **hapai.defaults.yaml** | Master configuration reference (all options) | YAML comments |
| **LICENSE** | MIT license | English |
| **AGENTS.md** | Cloud Function agent descriptions (internal) | English |

### External References

- **GitHub Releases** — Download tarballs and checksums at `github.com/renatobardi/hapai/releases`
- **Homebrew Formula** — `renatobardi/homebrew-hapai` tap (auto-updated on release)
- **Dashboard** — `renatobardi.github.io/hapai` (requires GitHub OAuth + GCP setup)

## Running Tests in CI

CI runs `bash tests/run-tests.sh` on both Ubuntu and macOS (see `.github/workflows/ci.yml`). Tests:
- Use bash assertions, no framework
- Create isolated `HAPAI_HOME` temp directories
- Validate all guardrails and core utilities
- Run in parallel on multiple OS versions

Add tests for any new feature or bug fix.

## Version Compatibility

**Minimum requirements:**
- Bash 4.0+ (macOS ships with Bash 3.2 — install via `brew install bash` if needed)
- jq 1.6+ (released 2018; widely available)
- Git 2.0+
- Python 3.12 (for Cloud Functions only; hooks are pure Bash)
- Node.js 20+ (for dashboard development only)

**Platform support:**
- ✅ macOS 10.15+ (Intel & Apple Silicon)
- ✅ Linux (Ubuntu, Debian, Alpine, CentOS, Fedora, etc.)
- ✅ WSL 2 (Windows Subsystem for Linux)
- ⚠️ Windows (Git Bash / MSYS2 — untested but likely compatible)

**Model versions:**
- Default review model: Claude Haiku 4.5 (fast, cost-effective for code review)
- Auto-fix model: Claude Sonnet 4.6 (requires `pr_review.auto_fix.enabled: true`)
- Note: Update model versions in `hapai.defaults.yaml` as new Claude versions ship

<!-- hapai:start -->
## Hapai Guardrails (enforced by hooks)

These rules are deterministically enforced by hapai hooks. Violations are blocked before execution.

- NEVER commit directly to protected branches (main, master)
- NEVER add Co-Authored-By or mention AI/Claude/Anthropic in commits, PRs, or docs
- NEVER run destructive commands (rm -rf, force-push, git reset --hard, DROP TABLE)
- NEVER edit .env, lockfiles, or CI workflow files without explicit permission
- ALWAYS create a feature branch before making changes
- ALWAYS keep commits focused — avoid touching many files/packages in a single commit
- ALWAYS use taxonomy prefix when creating branches: feat/, fix/, chore/, docs/, refactor/, test/, perf/, style/, ci/, build/, release/, hotfix/
- ALWAYS follow trunk-based workflow: short-lived branches from main, merged back to main via PR — no long-lived branches
<!-- hapai:end -->
