# hapai Changelog

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
