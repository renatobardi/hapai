# hapai

```
─── │  ╦ ╦╔═╗╔═╗╔═╗╦
    │  ╠═╣╠═╣╠═╝╠═╣║
    │  ╩ ╩╩ ╩╩  ╩ ╩╩
        guardrails for AI coding assistants
```

[![Pure Bash](https://img.shields.io/badge/Pure%20Bash-Yes-green?style=flat-square)](https://github.com/renatobardi/hapai)
[![CI/CD](https://img.shields.io/github/actions/workflow/status/renatobardi/hapai/ci.yml?style=flat-square)](https://github.com/renatobardi/hapai/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/renatobardi/hapai?style=flat-square)](LICENSE)

> Deterministic guardrails for AI coding assistants. Hooks that enforce rules **before execution** — not probabilistic prompts that get ignored.

**hapai** v1.6+ combines shell-based enforcement hooks with a cloud-native analytics dashboard. It intercepts Claude Code, Cursor, and Copilot tool calls in real-time and blocks violations immediately. When combined with Cloud Storage + BigQuery + GitHub Pages, it provides real-time visibility into guard enforcement across your team.

## What's New in v1.6.2

- **Drill-down analytics (L2)** — Click any guard bar or hotspot to open an inline panel with mini-timeline, breakdown bars (by tool or by guard), and recent events list
- **Event detail drawer (L3)** — Click any event to open a full detail drawer with ← Previous / Next → navigation and Escape key support
- **Rate cards** — Two new KPI cards: Allow Rate and Deny Rate (percentages), calculated from `allow_count` / `total_events` returned by BigQuery
- **Backend parameterization** — All BigQuery queries now accept `period` (7/14/30 days), `limit`/`offset` for pagination, and per-entity filters; injection-safe via `bigquery.ScalarQueryParameter`
- **Period selector connected to BQ** — Switching 7d/14d/30d triggers a real reload from BigQuery, not a client-side slice
- **Server-side drilldown detail** — `hook_detail` and `tool_detail` BQ queries return timeline + breakdown + recent events + stats for the selected entity
- **Load more from server** — Events table supports server-side pagination (`offset`-based) beyond the initial 100 rows
- **StatCard sparklines** — Trend sparkline (80×24px canvas) and directional arrow (↗/↘/→) on each KPI card
- **Dead code removed** — `TrendChart`, `ToolsChart`, and `ProjectsChart` deleted; superseded by sparklines, `TimelineChart`, and `Hotspots` tabs

## The Problem

AI coding tools frequently ignore markdown instructions and safety guidelines. They commit to protected branches, edit secrets files, run destructive commands, and add AI attribution despite explicit rules.

**Why this happens:** LLMs see markdown as suggestions, not requirements.

**The solution:** Deterministic enforcement via hooks running *before* the action, not after.

## Quick Start

```bash
# Clone
git clone https://github.com/renatobardi/hapai.git ~/hapai

# Add to PATH
ln -sf ~/hapai/bin/hapai /usr/local/bin/hapai

# Install globally (all projects)
hapai install --global

# Or per-project
cd your-project && hapai install --project

# Verify
hapai validate
```

## Guardrails (Block Before Execution)

| Guardrail | What it prevents | Config key |
|-----------|-----------------|-----------|
| **Branch Protection** | Commits/pushes/`gh api` deletions on protected branches (main, master, etc.) | `branch_protection.protected` |
| **Branch Taxonomy** | Enforces naming conventions (feat/, fix/, chore/, etc.) | `branch_taxonomy.allowed_prefixes` |
| **Branch Rules** | Validates description + origin branch | `branch_rules.enabled` |
| **Commit Hygiene** | Co-Authored-By, AI mentions, "Generated with Claude" | `commit_hygiene.blocked_patterns` |
| **File Protection** | Writes to .env, lockfiles, CI workflow files | `file_protection.protected` |
| **Destructive Commands** | `rm -rf`, `git push --force`, `git reset --hard`, `DROP TABLE` | `command_safety.blocked` |
| **Blast Radius** | Large commits touching too many files or packages | `blast_radius.max_files` |
| **Uncommitted Changes** | AI overwriting your uncommitted work | `uncommitted_changes.enabled` |
| **PR Review** | Background code review on all PRs (with optional auto-fix) | `pr_review.enabled` |
| **Git Workflow** | Trunk-based or GitFlow enforcement | `git_workflow.model` |

All guardrails support `fail_open`:
- **`fail_open: false`** — Block execution, show error
- **`fail_open: true`** — Warn but allow (soft constraints)

## Automations

Automations run in the background after tool execution, enabling proactive code fixes and improvements.

### Auto-Fix for PR Review Issues

When code review finds issues, **automatically attempt to fix them before blocking the push**.

**How it works:**
1. Code review detects issues (critical, high, medium, or low severity)
2. If `auto_fix.enabled: true`, launch background fix agent
3. Fix agent invokes a model to apply corrections to the code
4. Re-run review synchronously to validate fixes
5. If all issues resolved → allow push (`fix_clean` state)
6. If issues remain after max attempts → block push with list of failures (`fix_failed` state)

**Configuration:**
```yaml
guardrails:
  pr_review:
    auto_fix:
      enabled: false              # opt-in (requires pr_review.enabled=true)
      model: "claude-sonnet-4-6"  # model for applying fixes
      max_fix_attempts: 2         # rounds of fix → re-review → fix
      severities:                 # which issues to auto-fix
        - critical
        - high
        - medium
        - low
```

**Disabled by default** — double opt-in ensures this is explicit and project-aware.

## Analytics Dashboard

Deploy a real-time analytics dashboard to GitHub Pages to monitor guardrail events across your team.

### Features

- **Timeline** — Daily denial/warning counts (30-day rolling window)
- **Top Blocking Hooks** — Which guardrails are most active
- **Guardrail Activity** — Live feed of all blocked actions and warnings
- **Tool Distribution** — Which tools trigger guards most
- **Project Breakdown** — Per-project statistics
- **Deny Rate Trend** — Historical deny rate analysis

### Setup

1. Create Firebase project with GitHub OAuth provider
2. Set GitHub Actions secrets (VITE_FIREBASE_API_KEY, VITE_FIREBASE_APP_ID, VITE_BQ_PROXY_URL)
3. Merge to main → GitHub Actions builds and deploys to GitHub Pages
4. Dashboard live at: `https://{owner}.github.io/{repo}/`

See [`infra/gcp/SETUP.md`](infra/gcp/SETUP.md) for complete setup guide.

## Cloud Logging (Optional)

Sync audit logs to GCP for enterprise analytics and compliance.

**Architecture:**
```
~/.hapai/audit.jsonl
    ↓ hapai sync (local — ADC or service account key)
gs://hapai-audit-{name}/YYYY-MM/DD.jsonl
    ↓ bq load (part of hapai sync, or daily via hapai-sync.yml CI workflow)
hapai_dataset.events  (BigQuery)
    ↓ Cloud Function bq-query (Firebase auth required)
Analytics Dashboard  (GitHub Pages)
```

**Auto-sync — get data to GCS automatically:**

| Method | When | How |
|--------|------|-----|
| **Claude Code** | Session end | `gcp.auto_sync.enabled: true` in `hapai.yaml` |
| **Cursor · Windsurf · Devin · Trae · Copilot** | After each commit | `hapai install --git-hooks` |
| **CI (safety net)** | Daily at 2h UTC | `hapai-sync.yml` — loads from GCS to BigQuery |

**Local sync:**
```bash
# Authenticate once
gcloud auth application-default login

# Sync audit log to GCS + BigQuery
hapai sync
```

**What you get:**
- Immutable audit trail in BigQuery
- Real-time dashboard with 30-day rolling analytics
- No service account keys locally (ADC via `gcloud auth application-default login`)
- No service account keys in CI (OIDC + Workload Identity)
- Automatic daily ingestion via `hapai-sync.yml` for any GCS data not yet in BigQuery

See [`infra/gcp/SETUP.md`](infra/gcp/SETUP.md) for setup instructions.

## Automations (Run After Execution)

| Automation | What it does | Config key |
|-----------|-------------|-----------|
| **Auto-Checkpoint** | Granular git snapshots per file edited | `automation.auto_checkpoint` |
| **Auto-Format** | Runs prettier/ruff/black after writes | `automation.auto_format` |
| **Auto-Lint** | Runs ESLint/ruff/pylint, reports issues | `automation.auto_lint` |
| **Squash on Stop** | Consolidates checkpoints into clean commits | `automation.auto_checkpoint.squash_on_stop` |

## CLI Commands

### Installation
```bash
hapai install --global        # Global (~/.hapai)
hapai install --project       # Per-project (./hapai/)
hapai install --git-hooks     # Post-commit auto-sync (Cursor/Windsurf/Devin/Trae/Copilot)
hapai uninstall [--global]    # Remove hooks
hapai uninstall --git-hooks   # Remove post-commit hook
hapai validate                # Verify installation
```

### Monitoring
```bash
hapai status                  # Hook registration and active guardrails
hapai audit [N]               # Show last N audit entries (default: 20)
```

### Emergency
```bash
hapai kill                    # Disable all hooks immediately
hapai revive                  # Re-enable hooks
```

### Export
```bash
hapai export --target cursor     # Generate Cursor rules
hapai export --target copilot    # Generate Copilot rules
hapai export --target claude     # Generate CLAUDE.md rules
```

## Configuration

YAML-based with three-tier fallback:
1. **Project** `./hapai.yaml` (overrides all)
2. **Global** `~/.hapai/hapai.yaml`
3. **Defaults** `hapai.defaults.yaml`

### Quick Start
```bash
cp hapai.defaults.yaml hapai.yaml
# Edit hapai.yaml for your project
```

### Example: Strict Settings
```yaml
version: "1.0"
risk_tier: high

guardrails:
  branch_protection:
    enabled: true
    protected: [main, develop]
    fail_open: false

  branch_taxonomy:
    enabled: true
    allowed_prefixes: [feat, fix, chore, docs, refactor]
    require_description: true
    fail_open: false

  blast_radius:
    enabled: true
    max_files: 5
    max_packages: 1
    fail_open: false  # Block large changes

  pr_review:
    enabled: true
    model: "claude-haiku-4-5-20251001"
    fail_open: false  # Require review to pass

automation:
  auto_format:
    enabled: true
    python: "ruff format {file}"
    javascript: "prettier --write {file}"
```

## Architecture

**Technology Stack:**
- **Hooks**: Pure Bash 4+ (~1,550 LOC)
- **CLI**: Pure Bash (~645 LOC)
- **Dashboard**: Svelte 5 + Vite
- **Backend**: Python Cloud Functions
- **Analytics**: BigQuery
- **Auth**: Firebase Auth + GitHub OAuth
- **Deployment**: GitHub Pages + OIDC

**Design Principles:**
- **Graceful Failure** — Hooks never crash Claude Code
- **Timeouts** — PreToolUse (7s), PostToolUse (5s), Stop (10s)
- **Modular** — One concern per file, 50-100 LOC
- **Immutable Audit** — Append-only JSONL audit log

**Directory Structure:**
```
~/.hapai/
├── hooks/
│   ├── _lib.sh (config, JSON I/O, audit)
│   ├── pre-tool-use/ (11 guardrails)
│   ├── post-tool-use/ (automations)
│   └── stop/ (session cleanup)
├── audit.jsonl (immutable audit log)
└── state/ (cross-session counters)

project-root/
├── hapai.yaml (project config)
├── infra/gcp/
│   ├── dashboard/ (Svelte 5 frontend)
│   ├── functions/ (Cloud Function)
│   └── SETUP.md (deployment guide)
├── .github/workflows/
│   ├── hapai-sync.yml (OIDC Cloud Storage sync)
│   └── deploy-dashboard.yml (GitHub Pages)
```

## Testing

```bash
bash tests/run-tests.sh
```

Pure bash assertions (no test framework). ~200 assertions covering:
- Unit tests for 11 guardrail modules
- Integration tests (config, JSON, audit)
- End-to-end tests (hooks, CLI)

## Requirements

- **bash 4+** (check: `bash --version`)
- **jq** (JSON parser)
- **git** (for guard scripts)
- **Node.js 24+** (for GitHub Actions workflows only)

For cloud logging (optional):
- **gcloud CLI** (Cloud Storage, Cloud Functions, BigQuery)
- **firebase-admin** (Python, Cloud Function runtime)

## Troubleshooting

**Q: Hooks aren't blocking. Why?**
```bash
hapai status              # Check registration
hapai audit               # See what hooks decided
# Edit hapai.yaml: ensure fail_open: false
```

**Q: How do I see hook execution?**
```bash
hapai audit 50 | jq      # Recent entries
tail -f ~/.hapai/audit.jsonl | jq  # Live stream
```

**Q: Can I disable a guardrail?**
```yaml
# In hapai.yaml
guardrails:
  branch_protection:
    enabled: false  # Disable specific guard
```

**Q: Custom guardrails?**

Create `~/.hapai/hooks/pre-tool-use/my-guard.sh`:
```bash
#!/bin/bash
source "$HAPAI_LIB"
# Your logic here
exit 0  # allow
# or exit 2  # deny
```

## License

MIT — See LICENSE file.

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:
- How to set up your development environment
- How to write and test new guardrails
- Commit conventions and PR process
- Philosophy and design principles

Quick checklist:
1. Add tests for new features (`bash tests/run-tests.sh`)
2. Follow bash conventions (`set -euo pipefail`, shellcheck)
3. Keep modules modular (50-100 LOC)
4. Document config keys in `hapai.defaults.yaml`
5. Update CHANGELOG.md

## Community

- **Report a bug:** [GitHub Issues](https://github.com/renatobardi/hapai/issues/new?template=bug_report.md)
- **Request a feature:** [GitHub Issues](https://github.com/renatobardi/hapai/issues/new?template=feature_request.md)
- **Setup Guide:** [infra/gcp/SETUP.md](infra/gcp/SETUP.md)
- **Developer Guide:** [CLAUDE.md](CLAUDE.md)
- **Usage Examples:** [USAGE.md](USAGE.md) (Portuguese)
