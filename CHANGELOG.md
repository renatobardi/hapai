# hapai Changelog

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
