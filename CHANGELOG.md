# hapai Changelog

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
