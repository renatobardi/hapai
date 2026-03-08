# OUTE GCP Infrastructure Scripts

Automated CLI scripts for deploying OUTE Dashboard on Google Cloud Platform.

## Quick Start

### 1. Initial Setup (First Time Only)

```bash
bash .gcp/setup.sh oute-app us-central1
```

This script:
- ✅ Creates GCP project
- ✅ Enables required APIs
- ✅ Creates Artifact Registry
- ✅ Sets up PostgreSQL
- ✅ Creates service accounts
- ✅ Generates GitHub Actions key

**Time:** ~15 minutes (mostly waiting for infrastructure to provision)

### 2. Create Secrets

```bash
bash .gcp/create-secrets.sh
```

This script:
- ✅ Generates secure DATABASE_URL
- ✅ Generates secure JWT_SECRET
- ✅ Stores in Google Secret Manager
- ✅ Shows secret values for backup

**Important:** Save the printed values securely (password manager, Vault, etc.)

### 3. Add GitHub Secrets

```bash
# Using gh CLI (recommended)
gh secret set GCP_PROJECT_ID -b "oute-app"
gh secret set GCP_REGION -b "us-central1"
gh secret set GCP_SA_KEY < keys/gh-key.json
```

### 4. Deploy Dashboard

#### First Deployment (Manual)

```bash
# Build locally
npm ci && npm run build -w 00_dashboard

# Build Docker image
docker build \
  --file packages/00_dashboard/Dockerfile \
  --tag oute-dashboard:local .

# Tag for Artifact Registry
docker tag oute-dashboard:local \
  us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest

# Push to Artifact Registry
docker push \
  us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest

# Deploy to Cloud Run
bash .gcp/deploy.sh dashboard staging staging-latest
```

#### Automatic Deployments (GitHub Actions)

```bash
# Push to staging branch (auto-deploys to staging)
git push origin feature-branch:staging

# Push to main branch (auto-deploys to production)
git push origin main
```

---

## Available Scripts

### `setup.sh` - Initial Infrastructure

**Usage:**
```bash
bash setup.sh [PROJECT_ID] [REGION] [BILLING_ACCOUNT_ID]
```

**Arguments:**
- `PROJECT_ID`: GCP project ID (default: "oute-app")
- `REGION`: GCP region (default: "us-central1")
- `BILLING_ACCOUNT_ID`: Billing account ID (optional)

**Example:**
```bash
bash setup.sh oute-app us-central1 01ABCD-EF1234-GH5678
```

**What it creates:**
- GCP Project
- Enabled APIs (Cloud Run, Cloud SQL, Artifact Registry, Secret Manager, etc.)
- Cloud SQL PostgreSQL 15 instance
- Artifact Registry Docker repository
- Service accounts (Cloud Run, GitHub Actions) with IAM roles
- Service account keys

---

### `deploy.sh` - Deploy to Cloud Run

**Usage:**
```bash
bash deploy.sh <service> <environment> [image_tag]
```

**Arguments:**
- `service`: Service to deploy (dashboard, auth-profile, projects)
- `environment`: Target environment (staging, production)
- `image_tag`: Docker image tag (default: latest)

**Examples:**
```bash
# Deploy dashboard to staging with specific tag
bash deploy.sh dashboard staging staging-latest

# Deploy auth-profile to production
bash deploy.sh auth-profile production v1.0.0

# Deploy projects to staging
bash deploy.sh projects staging abc123-sha
```

**What it does:**
- ✅ Verifies image exists in Artifact Registry
- ✅ Deploys to Cloud Run with correct configuration
- ✅ Sets environment variables (NODE_ENV)
- ✅ Injects secrets from Secret Manager (DATABASE_URL, JWT_SECRET)
- ✅ Performs health checks
- ✅ Returns service URL

---

### `create-secrets.sh` - Setup Secrets Manager

**Usage:**
```bash
bash create-secrets.sh
```

**What it creates:**
- `DATABASE_URL` secret with connection string to PostgreSQL
- `JWT_SECRET` secret with random 32-byte key

**Output:**
- Displays secret values (save them!)
- Shows commands to retrieve/update secrets later

---

## Directory Structure

```
.gcp/
├── README.md                    # This file
├── setup.sh                     # Initial infrastructure setup
├── deploy.sh                    # Deploy to Cloud Run
├── create-secrets.sh            # Create secrets in Secret Manager
└── keys/                        # Service account keys (git-ignored)
    └── gh-key.json              # GitHub Actions service account
```

---

## Common Workflows

### Deploy a New Version to Staging

```bash
# 1. Build locally
npm run build -w 00_dashboard

# 2. Build and push Docker image
docker build \
  --file packages/00_dashboard/Dockerfile \
  --tag oute-dashboard:local .

docker tag oute-dashboard:local \
  us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest

docker push \
  us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest

# 3. Deploy using script
bash deploy.sh dashboard staging staging-latest

# 4. Verify
curl https://<SERVICE_URL>
```

### Promote Staging to Production

```bash
# Tag the same image for production
docker tag \
  us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest \
  us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:v1.0.0

docker push \
  us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:v1.0.0

# Deploy to production
bash deploy.sh dashboard production v1.0.0
```

### Rollback to Previous Version

```bash
# View revisions
gcloud run revisions list \
  --service=oute-dashboard \
  --region=us-central1

# Rollback (set traffic to previous revision)
gcloud run services update-traffic oute-dashboard \
  --region=us-central1 \
  --to-revisions=<PREVIOUS_REVISION>=100
```

### View Deployment Logs

```bash
# Staging
gcloud run logs read oute-dashboard-staging \
  --region=us-central1 \
  --follow

# Production
gcloud run logs read oute-dashboard \
  --region=us-central1 \
  --follow
```

---

## GitHub Actions Workflows

Three workflows automate deployments based on git branches:

### `.github/workflows/deploy-staging-manual.yml`
- **Trigger:** Manual (click "Run workflow" in GitHub UI)
- **Deploy to:** Staging environment
- **Inputs:** Service, image tag

### `.github/workflows/deploy-on-staging-branch.yml`
- **Trigger:** Push to `staging` branch
- **Deploy to:** Staging environment (oute-dashboard-staging)
- **Automatic:** Builds, tests, pushes image, deploys

### `.github/workflows/deploy-on-main-branch.yml`
- **Trigger:** Push to `main` branch
- **Deploy to:** Production environment (oute-dashboard)
- **Automatic:** Builds, tests, pushes image, deploys, creates release

---

## Environment Variables

### In Cloud Run Deployment

Set via `--set-env-vars` in deploy.sh/gcloud command:

```bash
NODE_ENV=staging          # production, staging, or development
DEBUG=false               # Enable/disable debugging
LOG_LEVEL=info            # log, info, warn, error
```

### From Secret Manager

Automatically injected into Cloud Run container:

```bash
DATABASE_URL              # PostgreSQL connection string
JWT_SECRET                # JWT signing key
```

---

## Troubleshooting

### Scripts fail with "gcloud not found"

Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install

### Setup script hangs on PostgreSQL creation

PostgreSQL takes ~5 minutes to create. Script waits automatically. If it times out:

```bash
# Check status manually
gcloud sql instances describe oute-postgres --region=us-central1
```

### Deploy script says "Image not found"

Image hasn't been pushed to Artifact Registry yet:

```bash
# Build and push image first
docker build --file packages/00_dashboard/Dockerfile --tag oute-dashboard:local .
docker tag oute-dashboard:local us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest
docker push us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest
```

### Service deployed but returning 500 errors

Check logs:
```bash
gcloud run logs read oute-dashboard-staging --region=us-central1 --follow
```

Common issues:
- DATABASE_URL secret missing or invalid
- Service account lacks Cloud SQL permissions
- PostgreSQL instance not running

---

## Next Steps

1. **Read full documentation:** `GCP-DEPLOYMENT.md` in repo root
2. **Setup infrastructure:** Run `.gcp/setup.sh`
3. **Add GitHub secrets:** Use `gh secret set` commands
4. **Deploy manually first:** Use `.gcp/deploy.sh` to verify
5. **Commit to git:** Workflows will auto-deploy on push

---

## Security Notes

⚠️ **Important:**
- Never commit `.gcp/keys/` to git (already in .gitignore)
- Never commit secret values to git
- Store secret values in password manager (1Password, Bitwarden, etc.)
- Rotate service account keys every 90 days
- Review IAM roles regularly

---

## Support

For detailed troubleshooting and advanced configurations, see `GCP-DEPLOYMENT.md`.

For gcloud CLI reference: `gcloud run --help`
