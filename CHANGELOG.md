# hapai Changelog

## v1.7.0 (2026-04-16) — Dashboard Reform, Dedup Pipeline & Hook Enrichment

### Dashboard Complete Reform (PRs #51, #55, #56)

**Redesigned dashboard with tabbed layout and 7 new BigQuery queries**
- New tabbed navigation: Overview, Projects, Guardrails, Events — replaces single-scroll layout
- `KpiBar` component with period comparison (current vs previous), trend arrows, and sparklines
- `ProjectHealth` component — per-project health scores with deny rate, top guard, and event counts
- `DenialReasons` component — aggregated denial reasons ranked by frequency
- `GuardrailGlossary` component — all guards with descriptions, deny/warn counts, and drill-down links
- `Hotspots` component — tabbed guard/tool/project hotspot view (replaces removed ToolsChart + ProjectsChart)
- Dashboard.svelte refactored: `_loaded` flag prevents race condition between `onMount` and `$effect`; logout resets flag

**New BigQuery queries (Cloud Function `hapai-bq-query`)**
- `stats_comparison` — current vs previous period KPIs (denials, warnings, allows, rates)
- `project_health` — per-project deny rate, top guard, event timeline
- `denial_reasons` — top denial reasons with counts and percentages
- `context_breakdown` — file categories, risk categories, branches, patterns (from context RECORD)
- `hook_detail` — drill-down: mini-timeline + breakdown + recent events + stats per guard
- `tool_detail` — drill-down: mini-timeline + breakdown + recent events + stats per tool
- All queries use dedup CTE (`ROW_NUMBER() OVER PARTITION BY event_id`) and accept `period` parameter

**API layer hardened (PR #56)**
- 30-second fetch timeout with `AbortController` — prevents hung requests
- Per-HTTP-status error messages (401 session expired, 403 denied, 404 endpoint check)
- SonarQube-compliant exception handling (no empty catch blocks)
- Correct `VITE_BQ_PROXY_URL` pointing to `hapai-bq-query` Cloud Function

### Audit Dedup Pipeline (PR #49)

**Eliminated duplicate events across the full pipeline — 4 layers**
- **P0 — event_id generation**: `_audit_event_id()` in `_lib.sh` generates unique IDs: `<epoch_ms>-<hook>-<rand4hex>`
- **P1 — Flow-dispatcher guard**: `flow-dispatcher.sh` exports `HAPAI_FLOW_EXECUTOR=1`; guard hooks call `_is_flow_managed && exit 0` to avoid double-logging when invoked both standalone and via flow
- **P2 — Incremental sync**: `hapai sync` maintains `~/.hapai/state/sync_cursor` (line count); only sends delta. GCS path includes offset for idempotency
- **P3 — BigQuery MERGE**: Cloud Function uses `MERGE WHEN NOT MATCHED INSERT` keyed on `event_id`; batch-level Python dedup before MERGE; `_merge_rows_by_event_id()` with streaming insert fallback

### Hook Enrichment — Context Analytics (PR #52)

**Structured context RECORD in BigQuery for deep analytics**
- `deny()` and `warn()` now pass `context_json` through to `audit_log()` — every denial/warning carries structured metadata
- 22-field context schema: `git_op`, `target_branch`, `protection_type`, `enforcement_method`, `filename`, `file_category`, `risk_category`, `command_preview`, `files_staged_count`, `packages_touched_count`, and more
- All guard hooks enriched: guard-branch, guard-files, guard-blast-radius, guard-commit-msg, guard-destructive, guard-uncommitted emit context
- Enables dashboard analytics by file category, risk tier, branch, and enforcement method

### Hook Name Resolution (PR #50)

- `audit_log()` now resolves hook name via `BASH_SOURCE[]` array walk instead of `$0`
- Fixes `hook: "_lib"` pollution in audit logs (was 2.4M rows in BigQuery)
- All hooks now correctly identify themselves in audit entries

### Cloud Function Fixes (PRs #53, #54)

- **Gen2 CloudEvent format** — `load_audit_from_gcs` updated for Gen2 runtime (`cloud_event.data` instead of legacy format)
- **GCP sync enabled** — `hapai.yaml` project config now has `gcp.auto_sync.enabled: true`
- **Two Cloud Functions**: `load_audit_from_gcs` (Storage trigger) + `hapai-bq-query` (HTTP trigger for dashboard)

### Repo Hygiene

- `.claude/settings.json` and `.claude/hooks/` removed from version control and added to `.gitignore`
- PR review test setup restored after merge conflicts

### Key Commits

- `ae9d5b0` — fix(audit): eliminate duplicate events across the full pipeline (#49)
- `4496c05` — fix(audit): resolve hook name via BASH_SOURCE[] walk (#50)
- `96c1a81` — feat(dashboard): complete reform — hook enrichment + BigQuery context + redesigned dashboard (#51)
- `b9c62b0` — fix(_lib): pass context_json through deny() and warn() to audit_log (#52)
- `8739589` — fix(gcf): use Gen2 CloudEvent format in load_audit_from_gcs (#53)
- `beea4d4` — fix(config): enable GCP sync in project hapai.yaml (#54)
- `5f341fd` — fix(dashboard): correct BQ endpoint URL, add timeout and error diagnostics (#56)
- `fa6269d` — fix(sonar): handle JSON parse exception with logging

---

## v1.6.3 (2026-04-15) — Security: Close gh api Branch Deletion Bypass

### 🔒 Security

**Close `gh api` branch deletion bypass in `guard-branch.sh` (#48)**
- `guard-branch.sh` protected branches via `git push/commit/merge/rebase` pattern matching, but `gh api repos/.../git/refs/heads/BRANCH -X DELETE` achieved the same result without being intercepted — a REST-layer bypass
- Root cause: the `if: "Bash(git *)"` filter in `settings.hooks.json` prevented the hook from being invoked for `gh` commands at all
- Extended `guard-branch.sh` to detect and deny `gh api .../git/refs/heads/BRANCH -X DELETE` and `--method DELETE` (case-insensitive), extracting the branch name from the URL and checking against `is_protected_branch()`
- Added `blocklist_check` for the `gh api` path, consistent with the existing `git` path
- Split `settings.hooks.json` `if` filter into two separate entries (`Bash(git *)` and `Bash(gh api*)`) instead of relying on unverified `|` syntax inside `Bash(...)` conditionals
- 135/135 tests passing (+7 new cases: `-X DELETE`, `--method DELETE`, `-X delete` lowercase, `--method delete` lowercase, non-protected allow, GET read allow, `&&` chained deny)

---

## v1.6.2 (2026-04-11) — Dashboard Drill-Down, Event Detail & BQ Parameterization

### ✅ Delivered

**Drill-down analytics — L2 (PR #43)**
- `DrillDown.svelte` — new inline panel that opens below the selected guard/tool/project bar
- Shows mini CSS timeline, breakdown bars (tool breakdown for guards; guard breakdown for tools), and recent events list
- Dismissable with × button; closes on new dashboard load

**Event detail drawer — L3 (PR #43)**
- `EventDetail.svelte` — full-screen right drawer with guard, tool, project, reason, and timestamp
- ← Previous / Next → navigation across all visible events
- Escape key closes the drawer; `findIndex` uses `ts+hook+tool` composite key to survive store reloads

**Rate cards (PR #44)**
- Two new KPI StatCards: **Allow Rate** (green) and **Deny Rate** (red), shown as percentages
- BigQuery `stats` query extended to return `allow_count` and `total_events`

**Backend parameterization (PR #44)**
- All BQ queries accept `period` (7/14/30 days) via `bigquery.ScalarQueryParameter` — injection-safe
- `denials` query accepts `limit`, `offset`, `event_filter`, `hook_filter`, `tool_filter`
- New `hook_detail` and `tool_detail` queries: mini-timeline + breakdown + recent events + stats per entity
- `_validate_period()`, `_validate_safe_string()`, `_validate_limit()`, `_validate_offset()` helpers enforce input bounds

**Period selector connected to BQ (PR #44)**
- Switching 7d/14d/30d calls `setPeriod(idToken, period)` → `loadDashboard(idToken, period)` — real BQ reload
- All sub-queries respect the selected window consistently

**Server-side pagination (PR #44)**
- "Load more from server" button in events table appends next 100 rows via `loadMoreDenials(idToken)`
- `denialsHasMore` flag controls button visibility

**StatCard sparklines (PR #43/44)**
- 80×24px canvas sparkline on each KPI card, drawn via `getComputedStyle()` for design token colors
- Trend arrow (↗/↘/→) with `--color-trend-up/down/flat` tokens

**Fix: drilldown recent events period filter (post-PR #44)**
- `recent` sub-query in both `_query_hook_detail` and `_query_tool_detail` was missing the period time filter
- Now consistent with `timeline`, `breakdown`, and `stats_row` sub-queries

**Cleanup: remove dead chart components (PR #45)**
- Deleted `TrendChart.svelte`, `ToolsChart.svelte`, `ProjectsChart.svelte`
- Superseded by: sparklines + `TimelineChart` (TrendChart); `Hotspots.svelte` tabs (ToolsChart + ProjectsChart)

---

## v1.6.1 (2026-04-10) — ASCII Logo, Hook Cleanup & Docs

### ✅ Delivered

**ASCII Art Logo (PR #38, #39)**
- `print_logo()` and `print_logo_compact()` added to `bin/hapai` — logo renders on `status`, `validate`, and install output
- ASCII art also added to installer output and README header
- Fixed middle line alignment (gap on right, not left) and added leading newline for terminal spacing

**Installer: stale hook cleanup (PR #37)**
- `hapai install` now strips stale hapai hooks from `settings.json` before merging the current template
- Prevents ghost hook registrations from accumulating across installs when hook filenames change

**Auto-sync at session end (PR #36)**
- `hooks/stop/auto-sync.sh` — Stop hook: fires `hapai sync` at Claude Code session end (opt-in via `gcp.auto_sync.enabled: true`)
- `hooks/git/post-commit.sh` — Git post-commit hook: fires `hapai sync` after every commit; covers Cursor, Windsurf, Devin, Trae, Copilot, and plain git
- `hapai install --git-hooks` / `hapai uninstall --git-hooks` manage the post-commit hook
- Registered in `templates/settings.hooks.json` Stop event array

**CLAUDE.md expanded (8c299d2)**
- Added all 8 hook event types with directories
- Documented PR review pipeline and flow dispatcher matcher syntax
- Full exporters table (8 target tools)
- Added `risk_tier`, `pr_review.*`, `branch_taxonomy.*` config keys
- Added `version`, `install/uninstall --git-hooks` CLI commands

### 📝 Key commits

- `fa41d57` — feat: ASCII art logo for CLI, installer and README (#38)
- `e7f7ee9` — fix: correct logo icon middle line alignment (#39)
- `2fe38ac` — fix: add leading newline before logo output for terminal spacing
- `4fa72b4` — fix: strip stale hapai hooks before merging template on install (#37)
- `3710d5e` — feat: auto-sync audit log to GCS at session end (#36)
- `8c299d2` — docs: expand CLAUDE.md with missing hook types, PR review system, exporters, and config

---

## v1.6.0 (2026-04-10) — Dashboard Design System, i18n & Docs Sidebar

### ✅ Delivered

**Design System Tokens (PR #34)**
- 22 new CSS custom properties in `app.css`: surfaces, extended text/border scale, chart grid colors, shadows, transitions, and `--color-deny-area` for chart fill
- Replaced all hardcoded hex values in `LandingPage`, `Header`, and `TrendChart` with tokens
- Single source of truth: changing a token updates every component that references it

**Shared Component Library (PR #34)**
- `Button` — variant (`primary` / `secondary` / `ghost` / `danger`) + size (`sm` / `md` / `lg`) props
- `Card` — optional title + accent border color
- `Badge` — semantic type variants (`deny` / `warn` / `allow`)
- `EmptyState` — consistent empty state messaging
- All four components written in Svelte 5 runes syntax (`$props()`, `{@render children?.()}`)
- Migrated `Header`, `LandingPage`, `DenialsTable`, and chart components (~34 lines of duplicated styles removed)

**UX Copy Improvements — EN / PT-BR / ES-ES (PRs #32 & #34)**
- "Denials" → "Blocked Actions", "Warnings" → "Soft Warnings", "Recent Events" → "Guardrail Activity"
- "Reason" → "Details" in event table
- Chart titles: "Denials by Tool / Project"
- Expanded empty state messages per component
- All copy keys translated in all three locales

**Landing Page for Unauthenticated Visitors (PR #31)**
- Full landing page shown when not signed in (replaces blank auth gate)
- Communicates value proposition, key guardrails, and quick-start steps

**Docs Sidebar — Scroll Spy + Section Grouping (PR #34)**
- `IntersectionObserver` scroll spy: active section updates while scrolling (not just on click)
- Flat nav reorganized into 5 labeled groups: Getting Started, Configuration, Reference, Cloud, Help
- Scroll spy always selects the topmost visible section (tracks intersecting set, sorts by `offsetTop`)
- All group labels i18n'd in EN, PT-BR, and ES-ES

**Dashboard Layout Fix (PR #34)**
- `TrendChart` moved inside `.content` max-width container — no more full-bleed breakout on wide screens

**OAuth Sign-In Error Handling (PR #33)**
- `Header.svelte` now catches sign-in failures and displays error feedback
- Distinguishes `auth/popup-closed-by-user` (silent) from real errors (shown to user)
- `navigator.language` guarded for environments where it may be undefined

### 📝 Key commits

- `bce79b1` — fix/feat: design system tokens, shared components, UX copy & Docs sidebar (#34)
- `bc90ae2` — fix: handle OAuth sign-in errors in Header and guard navigator.language (#33)
- `fb0b78e` — feat: i18n — EN / PT-BR / ES-ES across all pages and components (#32)
- `b125a88` — feat: landing page for unauthenticated visitors (#31)

---

## v1.5.1 (2026-04-10) — CI Sync Pipeline Fix

### ✅ Delivered

**hapai-sync.yml rewritten (PR #27)**
- Replaced broken `./bin/hapai sync` call (runner had no `~/.hapai/audit.jsonl`) with two-step pipeline:
  1. Download today's audit log from GCS: `gs://hapai-audit-bardi/YYYY-MM/DD.jsonl`
  2. Load into BigQuery with `bq load --noreplace` (append, idempotent per day)
- Graceful skip when no file exists for the day (exit 0, no error)
- Hard fail (`exit 1`) when `bq load` itself fails — errors are now surfaced, not silently swallowed
- Uses OIDC + Workload Identity Federation (no service account keys in CI)
- Runs daily at 2h UTC + supports manual `workflow_dispatch`

### 📝 Commits

- `0d18538` — fix: rewrite hapai-sync workflow to load GCS data into BigQuery
- `62f83bb` — fix: download only today's GCS file, fail loudly on bq load error
- `1f55340` — fix: skip BigQuery load step when no audit file was downloaded

---

## v1.5.0 (2026-04-09) — Auto-Fix for PR Review Issues

### ✅ Delivered

**Automatic Issue Correction**
- New `_pr-fix-agent.sh` worker: automatically fixes issues found by code review before blocking push
- When code review detects issues, system now attempts to fix them automatically (opt-in via `auto_fix.enabled`)
- Fix agent invokes a model to apply corrections, then re-runs review synchronously to validate fixes
- Configurable loop: up to `max_fix_attempts` (default 2) rounds of fix → re-review → fix
- Severity filtering: only auto-fix issues matching configured severities (critical, high, medium, low)

**New State Transitions**
- `fixing` — auto-fix is running in background; user can retry push shortly
- `fix_clean` — all issues were auto-fixed; status resets to clean, push allowed
- `fix_failed` — auto-fix exhausted max attempts; issues remain, push blocked with list of failures

**Configuration (New)**
```yaml
guardrails:
  pr_review:
    auto_fix:
      enabled: false             # opt-in (double opt-in with pr_review.enabled)
      model: "claude-sonnet-4-6" # configurable model for fixes
      max_fix_attempts: 2        # rounds of fix → re-review
      severities:                # which severity levels to auto-fix
        - critical
        - high
        - medium
        - low
```

**Cost Optimization**
- Review agent remains Haiku (cheap, fast detection)
- Fix agent uses Sonnet (more capable for applying fixes)
- Configurable per project: `auto_fix.model` can be overridden in project `hapai.yaml`

### 📝 Commits

- `b5532b3` — feat: complete auto-fix implementation for PR review issues
- `15fe363` — feat: auto-fix for PR review issues (incomplete — tests need debugging)

---

## v1.4.3 (2026-04-09) — HowItWorksPage Template Syntax Fix

### ✅ Delivered

- Fixed `ReferenceError: file is not defined` crash when navigating to `#/docs`
- Root cause: `{file}` strings inside YAML code blocks in `HowItWorksPage.svelte` were interpreted by the Svelte compiler as JavaScript template expressions
- Fix: replaced with HTML entities `&#123;file&#125;` which render as `{file}` visually but are not processed by Svelte

### 📝 Commits

- `73d0f19` — fix: escape curly braces in HowItWorksPage code blocks to prevent Svelte template errors (#22)

---

## v1.4.2 (2026-04-09) — Dashboard UX Fixes

### ✅ Delivered

**Dashboard Navigation Fixes**
- Fixed "How it works" link not navigating to docs page (root cause: CSS `position: absolute` on `.nav` caused the link to be overlapped and unclickable by the "Sign In" button)
- Extracted shared `route` store (`stores/route.js`) with `hashchange` listener — routing is now decoupled from component lifecycle and auth loading state
- Route check now runs before auth loading gate so `#/docs` renders `HowItWorksPage` immediately
- "Dashboard" nav link hidden when user is not authenticated (previously always visible)
- Fixed `HowItWorksPage` sidebar sticky offset: `56px` → `80px` (actual header height)

**Logo & Style Fixes (PRs #14–#19)**
- Fixed logo variant selection for light/dark backgrounds (was inverted)
- Increased logo canvas width from 150px to 320px (text was being clipped)
- Fixed textY formula to prevent vertical clipping
- Header logo size increased 80% total (+40% + another +40%)
- Subtitle "Guardrails Analytics" font increased 50% (18px), color lightened to `#e8e8e8`
- AuthGate description text font increased 50% (21px), darkened for readability

### 📝 Commits

- `812df28` — fix: add How it works routing and hide Dashboard link when not logged in (#20)
- `b710621` — style: header logo +40%, subtitle layout e desc +50% (#19)
- `66addbd` — style: logo header +40% e melhora contraste dos textos (#18)
- `2ae9582` — fix: correct textY formula to prevent vertical clipping (#17)
- `ef3bf32` — fix: increase logo canvas width to fit full 'hapai' text (#15)
- `71f1bde` — fix: correct logo variant selection for light and dark backgrounds (#14)

---

## v1.4.1 (2026-04-08) — Node.js 24 Ready

### ✅ Delivered

**GitHub Actions Modernization**
- Upgraded all workflows to Node.js 24 (from deprecated Node.js 20)
- Set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` environment variable
- Updated workflows: ci.yml, deploy-dashboard.yml, hapai-sync.yml, release.yml
- Prevents future CI failures from Node.js 20 removal (September 2026)

### 📝 Commits
- `91beb18` — fix: add Node.js 24 environment variable to GitHub Actions workflows (#7)

---

## v1.4.0 (2026-04-08) — Modern Dashboard Redesign

### ✅ Delivered

**Frontend Modernization**
- Rewritten dashboard in **Svelte 5** (from vanilla JS)
- Vite build system (production-optimized)
- Modern BMW-inspired design system (minimalist, professional)
- Responsive grid layouts, improved UX

**Authentication Update**
- Switched from Google OAuth to **GitHub OAuth** via Firebase Auth
- Simplified OAuth flow (no Google Cloud Console setup required)
- Better developer experience for GitHub-based teams

**Backend Improvements**
- Dynamic project ID in BigQuery queries (multi-project support)
- Parameterized query templates (prevents hardcoded references)
- Fixed GitHub Pages environment configuration (removed problematic URL field)
- Upgraded deploy-pages action to v4 (fixes artifact lookup issues)

**Build & Deployment**
- Updated `.github/workflows/deploy-dashboard.yml` for Svelte build
- Node.js 20 setup with npm cache
- Environment variables for Firebase config
- Automatic deployment to GitHub Pages on main push

**Documentation**
- Updated `infra/gcp/SETUP.md` with GitHub OAuth setup (Phase 5)
- Documented GitHub Secrets workflow for CI/CD
- Clarified Firebase API key security (intentionally public for web SDKs)
- Updated dashboard test procedures (GitHub Auth)

### 🔐 Security Fixes

1. ✅ Parameterized BigQuery queries (prevents hardcoded project references)
2. ✅ Removed environment URL field (fixes GitHub Pages deploy-pages v4 compatibility)
3. ✅ Svelte 5 uses safe DOM creation (prevents XSS in denial table rendering)
4. ✅ Updated documentation to prevent user setup failures

### 📝 Commits

- `c922ca6` — feat: redesign dashboard with Svelte + BMW design system + GitHub Auth
- `76ea0f6` — fix: address code review issues on PR #6
- `c3c98af` — Merge pull request #6 (Svelte redesign)
- `926b1d7` — fix: upgrade deploy-pages action to v4 to fix artifact lookup

---

## v1.3.1 (2026-04-08) — OIDC + Cloud Dashboard Complete

### ✅ Delivered

**OIDC (Workload Identity Federation)**
- Workload Identity Pool: `github-pool`
- OIDC Provider: `github-provider` (GitHub Actions)
- Service account impersonation without keys on disk
- 600s token lifetime (auto-rotated)

**GitHub Actions Workflow**
- `.github/workflows/hapai-sync.yml` — daily sync @ 2 AM UTC
- OIDC token exchange via `google-github-actions/auth@v1`
- Uploads audit logs to `gs://hapai-audit-bardi/YYYY-MM/DD.jsonl`

**Cloud Function**
- Python 3.12 (gen2 runtime)
- HTTP endpoint: `https://us-east1-hapai-oute.cloudfunctions.net/load-audit-logs`
- Processes JSONL → BigQuery
- Auto-creates dataset/table with proper schema
- Input validation (regex, identifiers, bucket names)
- 90-day retention via time partitioning

**BigQuery**
- Dataset: `hapai_dataset` (auto-created)
- Table: `events` (partitioned by ts)
- Schema: ts, event, hook, tool, result, project

**Cloud Scheduler**
- Job: `hapai-sync-trigger`
- Schedule: Daily @ 2 AM UTC
- Uses OIDC service account authentication

**Dashboard**
- GitHub Pages: `https://hapai.oute.pro`
- OAuth2 sign-in (Google)
- Analytics panels:
  - Timeline (denials/warns per day)
  - Top hooks blocking
  - Recent denials (sortable table)
  - Tool distribution
  - Project breakdown
  - Trends (deny rate)

### 🔐 Security

- ✅ Zero service account keys (OIDC)
- ✅ Organization policy compliant (`iam.disableServiceAccountKeyCreation`)
- ✅ Repository-scoped access (only `renatobardi/hapai`)
- ✅ Audit trail in GCP Cloud Audit Logs
- ✅ Input validation + regex safety (Cloud Function)
- ✅ Least privilege IAM roles
- ✅ Short-lived tokens (600s) with auto-refresh

### 📊 Architecture

```
hapai sync (OIDC token)
    ↓
Cloud Storage (hapai-audit-bardi)
    ↓
Cloud Function (HTTP/Scheduler)
    ↓
BigQuery (hapai_dataset.events)
    ↓
Dashboard (GitHub Pages)
    ↓
https://hapai.oute.pro
```

### 🧪 Testing

```bash
# Trigger workflow
gh workflow run hapai-sync.yml

# Check Cloud Storage
gcloud storage ls gs://hapai-audit-bardi/ --recursive

# Query BigQuery
bq query 'SELECT * FROM hapai_dataset.events ORDER BY ts DESC LIMIT 10'

# Test Cloud Scheduler (immediate)
gcloud scheduler jobs run hapai-sync-trigger --location=us-east1

# View Cloud Function logs
gcloud functions logs read load-audit-logs --gen2 --limit 50
```

### 📝 Commits

- `ba14de0` — refactor: add input validation to Cloud Function
- `30d0497` — docs: update OIDC setup guide
- `9ee4120` — feat: deploy Cloud Function for BigQuery processing
- `6b453de` — chore: update OIDC provider in GitHub Actions workflow
- `0298448` — feat: OIDC authentication for hapai sync in GitHub Actions

### 🚀 Next Steps (Optional)

1. **Eventarc Trigger** — Auto-trigger Cloud Function on new files (currently using Cloud Scheduler)
2. **Custom Metrics** — Add more analytics queries to dashboard
3. **Alerts** — GCP Monitoring alerts for failures
4. **Multi-account** — Support multiple GCP projects

---

## v1.3.0 (2026-04-07) — Cloud Dashboard

Dashboard infrastructure with BigQuery, GitHub Pages, OAuth2 authentication.

---

## v1.2.0 (2026-03-20) — Hook Chains & State

Advanced guardrail chains, state counters, universal installer, Brew tap.

---

## v1.1.0 (2026-02-10) — Multi-tool Export

Export guardrails for Cursor, Copilot, Devin, etc.

---

## v1.0.0 (2026-01-15) — Initial Release

Pure Bash CLI, Cloud Code hooks, deterministic guardrails.
