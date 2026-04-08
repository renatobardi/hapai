# hapai v1.3 — OIDC Setup (Secure, No Service Account Keys!)

This guide sets up **Workload Identity Federation (OIDC)** so `hapai sync` can run in GitHub Actions without storing service account keys.

## Architecture

```
GitHub Actions Workflow
        ↓
GitHub OIDC Token
        ↓
GCP Workload Identity Pool & Provider
        ↓
Service Account Impersonation
        ↓
gsutil (Cloud Storage + BigQuery)
```

---

## Phase 1: Create Workload Identity Pool & Provider

### 1.1 Create the Pool

```bash
export PROJECT_ID="hapai-oute"
export POOL_NAME="github-pool"
export POOL_DISPLAY_NAME="GitHub"

gcloud iam workload-identity-pools create "$POOL_NAME" \
  --project="$PROJECT_ID" \
  --location=global \
  --display-name="$POOL_DISPLAY_NAME"
```

### 1.2 Create the Provider

```bash
export PROVIDER_NAME="github-provider"

gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_NAME" \
  --project="$PROJECT_ID" \
  --location=global \
  --workload-identity-pool="$POOL_NAME" \
  --display-name="GitHub" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.aud=assertion.aud" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

### 1.3 Grant Permissions

```bash
# Get the service account email
SA_EMAIL="hapai-sync@$PROJECT_ID.iam.gserviceaccount.com"

# Allow GitHub repo to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --principal="principalSet://iam.googleapis.com/projects/$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')/locations/global/workloadIdentityPools/$POOL_NAME/attribute.repository/renatobardi/hapai"
```

### 1.4 Get Workload Identity Provider Resource Name

```bash
gcloud iam workload-identity-pools providers describe "$PROVIDER_NAME" \
  --project="$PROJECT_ID" \
  --location=global \
  --workload-identity-pool="$POOL_NAME" \
  --format="value(name)"

# Copy this value — you'll need it for GitHub Actions
# Format: projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_NAME/providers/PROVIDER_NAME
```

---

## Phase 2: GitHub Actions Workflow

Create `.github/workflows/hapai-sync.yml`:

```yaml
name: hapai sync

on:
  schedule:
    # Daily at 2 AM UTC (adjust to your timezone)
    - cron: '0 2 * * *'
  workflow_dispatch:  # Allow manual trigger

permissions:
  contents: read
  id-token: write  # Required for OIDC token

jobs:
  sync:
    name: Sync audit logs to GCP
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud (OIDC)
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'hapai-sync@hapai-oute.iam.gserviceaccount.com'
          token_format: 'access_token'
          access_token_lifetime: '600s'

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Run hapai sync
        env:
          HAPAI_SYNC_PROJECT_ID: 'hapai-oute'
          HAPAI_SYNC_BUCKET: 'hapai-audit-bardi'
        run: |
          # Create hapai.yaml for this run
          cat > hapai.yaml <<EOF
          version: "1.0"
          risk_tier: medium
          gcp:
            enabled: true
            project_id: $HAPAI_SYNC_PROJECT_ID
            bucket: $HAPAI_SYNC_BUCKET
            region: us-east1
            retention_days: 90
          EOF
          
          # Run sync (GOOGLE_APPLICATION_CREDENTIALS not needed - using OIDC)
          ./bin/hapai sync

      - name: Slack notification (optional)
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "❌ hapai sync failed",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "Repository: ${{ github.repository }}\nRun: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
          SLACK_WEBHOOK_TYPE: INCOMING_WEBHOOK
```

---

## Phase 2.5: Cloud Function Deployment

Deploy the Cloud Function that processes audit logs from Cloud Storage to BigQuery:

```bash
gcloud functions deploy load-audit-logs \
  --gen2 \
  --runtime=python312 \
  --region=us-east1 \
  --source=infra/gcp/functions \
  --entry-point=load_audit_logs \
  --trigger-http \
  --allow-unauthenticated \
  --project=hapai-oute
```

**Function Details:**
- Reads JSONL from Cloud Storage bucket
- Loads records into BigQuery table
- Auto-creates dataset/table if missing
- 90-day retention via time partitioning
- HTTP endpoint for manual testing:
  ```bash
  curl https://us-east1-hapai-oute.cloudfunctions.net/load-audit-logs
  ```

**Eventarc Trigger (Optional, Advanced):**
To automatically trigger on new files, create an Eventarc trigger:
```bash
gcloud eventarc triggers create load-audit-trigger \
  --location=us-east1 \
  --destination-run-service=load-audit-logs \
  --destination-run-region=us-east1 \
  --event-filters="type=google.cloud.storage.object.v1.finalized" \
  --event-filters="bucket=hapai-audit-bardi" \
  --service-account="hapai-sync@hapai-oute.iam.gserviceaccount.com" \
  --project=hapai-oute
```

For now, the function can be triggered manually or via scheduled Cloud Scheduler job.

---

## Phase 3: Configuration

Update your `hapai.yaml`:

```yaml
version: "1.0"
risk_tier: medium

gcp:
  enabled: true
  project_id: hapai-oute
  bucket: hapai-audit-bardi
  region: us-east1
  retention_days: 90
```

---

## Testing

### Local Test (with OIDC token from GitHub Actions)

Not applicable — OIDC tokens are only issued by GitHub Actions.

### GitHub Actions Test

1. Push to main
2. Workflow triggers automatically (or use "Run workflow" button)
3. Check BigQuery: `bq query 'SELECT * FROM hapai_dataset.events ORDER BY ts DESC LIMIT 5'`

---

## Security Benefits

✅ **No service account keys on disk**  
✅ **Short-lived tokens** (default 1 hour, configure `access_token_lifetime`)  
✅ **Automatic rotation** (no key rotation needed)  
✅ **Audit trail** in GCP Cloud Audit Logs  
✅ **Organization policy compliant**  

---

## Troubleshooting

### "Invalid OIDC token"
- Ensure the service account principal includes your exact GitHub repo: `renatobardi/hapai`
- Check IAM binding: `gcloud iam service-accounts get-iam-policy hapai-sync@hapai-oute.iam.gserviceaccount.com`

### "Permission denied" on Cloud Storage
- Check service account has `roles/storage.objectAdmin` on the bucket
- Check service account has `roles/bigquery.dataEditor` on the dataset

### Workflow fails with "authentication failed"
- Verify `workload_identity_provider` and `service_account` values in `.github/workflows/hapai-sync.yml`
- Check that the GitHub OIDC provider is configured correctly in GCP

---

## References

- [Google Workload Identity Federation](https://cloud.google.com/docs/authentication/workload-identity-federation)
- [GitHub OIDC Token](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [google-github-actions/auth](https://github.com/google-github-actions/auth)
