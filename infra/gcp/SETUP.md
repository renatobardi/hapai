# hapai v1.3 — Cloud Dashboard Setup Guide

This guide walks you through setting up the hapai Cloud Dashboard infrastructure on Google Cloud Platform (GCP).

## Prerequisites

- Active GCP project (already created)
- `gcloud` CLI installed locally
- `gsutil` installed (comes with Google Cloud SDK)
- Authenticated to GCP: `gcloud auth application-default login`

## Architecture

```
hapai audit.jsonl (local)
    ↓
hapai sync (uploads via gsutil)
    ↓
Cloud Storage (gs://hapai-audit-{username})
    ↓
Cloud Function (triggered on upload)
    ↓
BigQuery (hapai_dataset.events table)
    ↓
GitHub Pages Dashboard (OAuth2 → BigQuery REST API)
    ↓
https://renatobardi.github.io/hapai
```

---

## Phase 1: Create GCP Resources

### 1.1 Set Your GCP Project

```bash
# Set the project ID (replace with your actual project ID)
export GCP_PROJECT_ID="hapai-oute"
gcloud config set project "$GCP_PROJECT_ID"

# Verify
gcloud config get-value project
```

### 1.2 Create Cloud Storage Bucket

```bash
# Create bucket for audit logs (region: us-east1)
gsutil mb -l us-east1 "gs://hapai-audit-$(whoami)"

# Verify
gsutil ls
```

### 1.3 Create BigQuery Dataset

```bash
# Create dataset with US location
bq mk --dataset --location=US --description="hapai audit logs" hapai_dataset

# Verify
bq ls -d
```

### 1.4 Create Service Account

```bash
# Create service account
gcloud iam service-accounts create hapai-sync \
  --display-name="hapai audit sync"

# Get the email
SA_EMAIL=$(gcloud iam service-accounts list --filter="displayName:hapai-sync" --format="value(email)")
echo "Service Account: $SA_EMAIL"
```

### 1.5 Grant Permissions to Service Account

```bash
# Cloud Storage: write access to bucket
gsutil iam ch "serviceAccount:$SA_EMAIL:objectCreator" "gs://hapai-audit-$(whoami)"
gsutil iam ch "serviceAccount:$SA_EMAIL:objectAdmin" "gs://hapai-audit-$(whoami)"

# BigQuery: read/write access to dataset and tables
bq update --set_iam_policy=/dev/stdin hapai_dataset <<EOF
{
  "bindings": [
    {
      "role": "roles/bigquery.dataEditor",
      "members": [
        "serviceAccount:$SA_EMAIL"
      ]
    }
  ]
}
EOF
```

### 1.6 Generate Service Account Key

```bash
# Create JSON key
mkdir -p ~/.config
gcloud iam service-accounts keys create ~/.config/gcp-sa-key.json \
  --iam-account="$SA_EMAIL"

# Verify the file was created
ls -la ~/.config/gcp-sa-key.json

# Restrict permissions (important for security)
chmod 600 ~/.config/gcp-sa-key.json

echo "✓ Service account key saved to ~/.config/gcp-sa-key.json"
```

---

## Phase 2: Deploy Cloud Function

The Cloud Function automatically loads JSONL files from Cloud Storage to BigQuery.

### 2.1 Create Cloud Function

```bash
# Set environment variables
export FUNCTION_NAME="hapai-load-audit"
export BUCKET_NAME="hapai-audit-$(whoami)"
export SA_EMAIL=$(gcloud iam service-accounts list --filter="displayName:hapai-sync" --format="value(email)")

# Deploy the function
gcloud functions deploy "$FUNCTION_NAME" \
  --runtime python311 \
  --trigger-resource "$BUCKET_NAME" \
  --trigger-event google.storage.object.finalize \
  --entry-point load_audit_from_gcs \
  --source ./infra/gcp/functions \
  --memory 256MB \
  --timeout 60 \
  --service-account "$SA_EMAIL" \
  --set-env-vars GCP_PROJECT_ID="$GCP_PROJECT_ID"

echo "✓ Cloud Function deployed"
```

### 2.2 Verify Cloud Function

```bash
# List functions
gcloud functions list

# View function details
gcloud functions describe "$FUNCTION_NAME"

# View logs (check for errors)
gcloud functions logs read "$FUNCTION_NAME" --limit 50
```

---

## Phase 3: Configure hapai Local Sync

### 3.1 Create hapai.yaml in Your Project

```bash
# In your project root
cat > hapai.yaml <<EOF
version: "1.0"
risk_tier: medium

gcp:
  enabled: true
  project_id: $GCP_PROJECT_ID
  bucket: hapai-audit-$(whoami)
  region: us-east1
  retention_days: 90

# ... rest of your hapai config ...
EOF
```

### 3.2 Test Local Sync

```bash
# Set credentials
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcp-sa-key.json

# Dry run (no upload)
hapai sync --dry-run

# Actual sync
hapai sync

# Verify upload
gsutil ls -r "gs://hapai-audit-$(whoami)/"
```

### 3.3 Set Up Automated Daily Sync

Add to crontab:

```bash
crontab -e
```

Add this line:

```bash
0 2 * * * GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcp-sa-key.json /usr/local/bin/hapai sync 2>&1 >> ~/.hapai/sync.log
```

This runs at 2 AM daily, syncing your audit logs to Cloud Storage.

Monitor the log:

```bash
tail -f ~/.hapai/sync.log
```

---

## Phase 4: Dashboard Setup (GitHub Pages)

### 4.1 Create GitHub Pages Branch

```bash
# Create gh-pages branch from main
git checkout -b gh-pages

# Note: For custom domain setup (optional), see section 4.3 below
# git add CNAME && git commit -m "setup: github pages cname" && git push -u origin gh-pages

# Switch back to main
git checkout main
```

### 4.2 Configure Repository Settings

1. Go to: **Settings** → **Pages**
2. Set:
   - **Source**: Deploy from a branch
   - **Branch**: gh-pages
   - **Folder**: / (root)
3. Check **Enforce HTTPS**

### 4.3 (Optional) Configure Custom Domain (DNS)

If you want to use a custom domain (e.g., `hapai.oute.pro`) instead of the default GitHub Pages URL:

On your domain registrar (e.g., Route53, Cloudflare):
1. Create a CNAME file: `echo "your-domain.com" > CNAME`
2. Add CNAME record to your registrar:
   - Name: your-domain.com
   - Type: CNAME
   - Value: renatobardi.github.io

Wait for DNS propagation (usually < 5 minutes):

```bash
dig your-domain.com
# Should resolve to 185.199.108.153 (GitHub Pages)
```

---

## Phase 5: Dashboard Authentication Configuration

The dashboard uses **GitHub OAuth** via Firebase Authentication. No manual OAuth configuration needed—use GitHub Secrets in the deployment workflow instead.

### 5.1 Get Firebase Configuration

1. Go to: **Firebase Console** → Your Project → **Project Settings**
2. Under **Your apps**, select the web app (or create one)
3. Copy these values from the **SDK config**:
   - `apiKey`
   - `appId`
   - `projectId`

### 5.2 Configure Deployment Secrets

The dashboard builds automatically when you merge to `main`. The GitHub Actions workflow needs these secrets configured:

1. Go to: **GitHub** → **Settings** → **Secrets and variables** → **Actions**
2. Add these secrets:
   - `VITE_FIREBASE_API_KEY` ← Firebase API Key from 5.1
   - `VITE_FIREBASE_APP_ID` ← Firebase App ID from 5.1
   - `VITE_BQ_PROXY_URL` ← Your Cloud Function URL (e.g., `https://your-region-gcp-project.cloudfunctions.net/bq-query`)

The workflow (`.github/workflows/deploy-dashboard.yml`) uses these to build the dashboard with GitHub OAuth enabled.

**Note:** The `VITE_FIREBASE_API_KEY` is intentionally public—Firebase SDKs require public API keys for web apps. This is secure; users cannot access your Firebase project's data without proper authentication.

---

## Phase 6: Test End-to-End

### 6.1 Trigger Cloud Function Manually

```bash
# Upload a test JSONL file
echo '{"ts":"2026-04-08T10:00:00Z","event":"deny","hook":"guard-branch","tool":"Bash","result":"protected branch","project":"/Users/bardi/Projetos/hapai"}' | \
  gsutil cp - "gs://hapai-audit-$(whoami)/2026-04/08-test.jsonl"

# Check Cloud Function logs
gcloud functions logs read hapai-load-audit --limit 20
```

### 6.2 Query BigQuery

```bash
# Check if data arrived
bq query --use_legacy_sql=false '
  SELECT * FROM `hapai_dataset.events` 
  ORDER BY ts DESC 
  LIMIT 5
'
```

### 6.3 Visit Dashboard

Open: https://renatobardi.github.io/hapai

1. Click "Sign in with GitHub"
2. Authorize the application via GitHub
3. You should see your audit log data visualized in charts

---

## Troubleshooting

### Cloud Function Logs Show Errors

```bash
gcloud functions logs read hapai-load-audit --limit 50
```

Common issues:
- **Permission denied**: Check service account roles (BigQuery, Cloud Storage)
- **Dataset not found**: Run the Cloud Function again (it auto-creates the dataset)
- **JSON parsing errors**: Check audit.jsonl format

### Dashboard Shows "Authentication expired"

- Clear browser localStorage: `localStorage.clear()`
- Sign in again

### BigQuery Query Returns Empty

- Check if Cloud Function was triggered: `gcloud functions logs read hapai-load-audit`
- Verify file upload: `gsutil ls gs://hapai-audit-*/`
- Check if data has right format: `gsutil cp gs://hapai-audit-*/**.jsonl - | head`

### gsutil: command not found

Install Google Cloud SDK:

```bash
# macOS
brew install --cask google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash

# Reinitialize
exec -l $SHELL
gcloud init
```

---

## Monitoring & Maintenance

### Check Daily Sync Status

```bash
tail ~/.hapai/sync.log
```

### Monitor Cloud Function

```bash
# Last 100 executions
gcloud functions logs read hapai-load-audit --limit 100

# Filter errors only
gcloud functions logs read hapai-load-audit --limit 100 | grep -i error
```

### BigQuery Retention

Data is automatically deleted after 90 days (configured in Cloud Function).

To adjust:

```python
# Edit infra/gcp/functions/load-audit.py, change:
expiration_ms=90 * 24 * 3600 * 1000,  # Change 90 to desired days
```

Then re-deploy:

```bash
gcloud functions deploy hapai-load-audit \
  --source ./infra/gcp/functions \
  --entry-point load_audit_from_gcs \
  --runtime python311
```

---

## Self-Hosting the Dashboard

By default, CORS is allowed from `renatobardi.github.io` and localhost (for development).

To allow your own domain, set the env var when deploying the `hapai-bq-query` Cloud Function:

```bash
gcloud functions deploy hapai-bq-query \
  --source ./infra/gcp/functions \
  --entry-point hapai_bq_query \
  --runtime python312 \
  --set-env-vars CORS_ORIGINS=https://yourdomain.com
```

For multiple origins (comma-separated):

```bash
gcloud functions deploy hapai-bq-query \
  --source ./infra/gcp/functions \
  --entry-point hapai_bq_query \
  --runtime python312 \
  --set-env-vars CORS_ORIGINS=https://yourdomain.com,https://another.domain.com
```

The function will use your custom origins instead of the defaults.

---

## Security Notes

- Keep `~/.config/gcp-sa-key.json` **private** and in `.gitignore`
- Service account key is loaded via `GOOGLE_APPLICATION_CREDENTIALS` env var
- BigQuery data is read-only from the dashboard (OAuth2 signs in as your user account)
- Use HTTPS only for custom domain
- Rotate service account keys every 90 days
