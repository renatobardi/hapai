# OUTE GCP Deployment Guide

Complete guide to deploy OUTE Dashboard on Google Cloud Platform using Cloud Run, with GitHub Actions CI/CD integration.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Building & Pushing Images](#building--pushing-images)
4. [Deploying to Cloud Run](#deploying-to-cloud-run)
5. [GitHub Actions Integration](#github-actions-integration)
6. [Monitoring & Logs](#monitoring--logs)
7. [Troubleshooting](#troubleshooting)
8. [Rollback Procedures](#rollback-procedures)

---

## Prerequisites

### Required Tools
- **gcloud CLI** - [Install](https://cloud.google.com/sdk/docs/install)
- **Docker** - [Install](https://docs.docker.com/get-docker/)
- **gh CLI** (optional) - [Install](https://cli.github.com/)
- **Node.js 20+** - [Install](https://nodejs.org/)

### Required Access
- GCP account with billing enabled
- GitHub repository access (push + secrets)
- Sufficient GCP quotas (Cloud Run, Cloud SQL, Artifact Registry)

### Verify Installation
```bash
gcloud version
docker version
gh version
node --version
```

---

## Initial Setup

### Step 1: Set GCP Configuration

```bash
# Set default project (replace with your project ID)
export PROJECT_ID="oute-app"
export GCP_REGION="us-central1"

gcloud config set project $PROJECT_ID
gcloud config set compute/region $GCP_REGION

# Verify
gcloud config list
```

### Step 2: Run Automated Setup Script

The setup script automates all infrastructure creation:

```bash
# From repository root
bash .gcp/setup.sh $PROJECT_ID $GCP_REGION

# If you have a billing account
bash .gcp/setup.sh $PROJECT_ID $GCP_REGION YOUR_BILLING_ACCOUNT_ID
```

**What this script does:**
- Creates GCP project
- Enables required APIs
- Creates Artifact Registry docker repository
- Creates Cloud SQL PostgreSQL instance
- Creates service accounts with proper IAM roles
- Generates service account keys

### Step 3: Create Secrets

```bash
# Create DATABASE_URL and JWT_SECRET secrets
bash .gcp/create-secrets.sh

# The script will output secret values - SAVE THEM SECURELY
# Store in password manager, 1Password, Vault, etc.
```

### Step 4: Verify Infrastructure

```bash
# Check project
gcloud projects describe $PROJECT_ID

# Check APIs enabled
gcloud services list --enabled | grep -E "run|artifact|sql|secret"

# Check Cloud SQL instance
gcloud sql instances list
gcloud sql databases list --instance=oute-postgres

# Check Artifact Registry
gcloud artifacts repositories list

# Check service accounts
gcloud iam service-accounts list

# Check secrets
gcloud secrets list
```

---

## Building & Pushing Images

### Build Locally (Test)

```bash
cd /Users/bardi/Projetos/oute-main

# Build the dashboard image
docker build \
  --tag oute-dashboard:local \
  --file packages/00_dashboard/Dockerfile \
  .

# Verify the build worked
docker images | grep oute-dashboard
```

### Tag for Artifact Registry

```bash
# Set variables
export IMAGE_NAME="oute-dashboard"
export IMAGE_TAG="staging-latest"
export REGISTRY="${GCP_REGION}-docker.pkg.dev"

# Tag the image
docker tag oute-dashboard:local \
  ${REGISTRY}/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:${IMAGE_TAG}

# Verify tagging
docker images | grep $REGISTRY
```

### Push to Artifact Registry

```bash
# Authenticate Docker with Artifact Registry
gcloud auth configure-docker ${GCP_REGION}-docker.pkg.dev

# Push the image
docker push ${REGISTRY}/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:${IMAGE_TAG}

# Verify push was successful
gcloud artifacts docker images list ${REGISTRY}/${PROJECT_ID}/docker-repo

# Show image details
gcloud artifacts docker images describe \
  ${REGISTRY}/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:${IMAGE_TAG}
```

---

## Deploying to Cloud Run

### Deploy to Staging

```bash
# Option 1: Use the deploy script (recommended)
bash .gcp/deploy.sh dashboard staging staging-latest

# Option 2: Manual gcloud command
gcloud run deploy oute-dashboard-staging \
  --image=${REGISTRY}/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:staging-latest \
  --platform=managed \
  --region=$GCP_REGION \
  --service-account=cloud-run-sa@${PROJECT_ID}.iam.gserviceaccount.com \
  --memory=512Mi \
  --cpu=1 \
  --timeout=3600 \
  --port=3000 \
  --allow-unauthenticated \
  --set-env-vars="NODE_ENV=staging" \
  --set-secrets="DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest"
```

### Get Service URL

```bash
# Get the staging service URL
gcloud run services describe oute-dashboard-staging \
  --region=$GCP_REGION \
  --format='value(status.url)'

# Store for testing
export STAGING_URL=$(gcloud run services describe oute-dashboard-staging \
  --region=$GCP_REGION \
  --format='value(status.url)')

echo "Staging URL: $STAGING_URL"
```

### Test Staging Deployment

```bash
# Health check
curl -v $STAGING_URL

# View logs
gcloud run logs read oute-dashboard-staging \
  --region=$GCP_REGION \
  --limit=50

# Real-time logs (follow)
gcloud run logs read oute-dashboard-staging \
  --region=$GCP_REGION \
  --follow
```

### Deploy to Production

```bash
# Tag for production
export IMAGE_TAG_PROD="v1.0.0"

docker tag ${REGISTRY}/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:staging-latest \
  ${REGISTRY}/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:${IMAGE_TAG_PROD}

docker push ${REGISTRY}/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:${IMAGE_TAG_PROD}

# Deploy to Cloud Run production
gcloud run deploy oute-dashboard \
  --image=${REGISTRY}/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:${IMAGE_TAG_PROD} \
  --platform=managed \
  --region=$GCP_REGION \
  --service-account=cloud-run-sa@${PROJECT_ID}.iam.gserviceaccount.com \
  --memory=512Mi \
  --cpu=1 \
  --timeout=3600 \
  --port=3000 \
  --allow-unauthenticated \
  --set-env-vars="NODE_ENV=production" \
  --set-secrets="DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest"

# Get production URL
gcloud run services describe oute-dashboard \
  --region=$GCP_REGION \
  --format='value(status.url)'
```

---

## GitHub Actions Integration

### Setup GitHub Secrets & Variables

#### Add Repository Secrets

Secrets are sensitive and not visible in logs/UI after creation.

```bash
# Using gh CLI (recommended)
gh secret set GCP_PROJECT_ID -b "$PROJECT_ID"
gh secret set GCP_REGION -b "$GCP_REGION"
gh secret set GCP_SA_KEY < .gcp/keys/gh-key.json

# Verify secrets were added
gh secret list

# If gh CLI not available, add manually:
# Go to: https://github.com/renatobardi/oute-main/settings/secrets/actions
# Click "New repository secret" and add:
#   - GCP_PROJECT_ID: oute-app
#   - GCP_REGION: us-central1
#   - GCP_SA_KEY: (paste contents of .gcp/keys/gh-key.json)
```

#### Add Environments (Optional)

For better separation of staging/production deployments:

```bash
# Create staging environment
gh api repos/renatobardi/oute-main/environments/staging \
  --input -

# Create production environment
gh api repos/renatobardi/oute-main/environments/production \
  --input -
```

Or via GitHub UI: Settings → Environments → New environment

### Verify Workflows

```bash
# List workflows
gh workflow list

# View workflow runs
gh run list --workflow=deploy-on-staging-branch.yml

# View a specific run
gh run view <run_id>

# View workflow logs
gh run view <run_id> --log
```

---

## Monitoring & Logs

### View Service Details

```bash
# Staging service
gcloud run services describe oute-dashboard-staging --region=$GCP_REGION

# Production service
gcloud run services describe oute-dashboard --region=$GCP_REGION
```

### View Logs

```bash
# Last 50 lines (staging)
gcloud run logs read oute-dashboard-staging --region=$GCP_REGION --limit=50

# Real-time logs (staging)
gcloud run logs read oute-dashboard-staging --region=$GCP_REGION --follow

# Filter by severity
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=oute-dashboard-staging AND severity=ERROR" \
  --region=$GCP_REGION \
  --limit=50 \
  --format=json

# Search for specific error
gcloud logging read \
  'resource.type="cloud_run_revision" AND textPayload=~"database connection error"' \
  --region=$GCP_REGION \
  --limit=100
```

### View Revisions

```bash
# List all revisions (staging)
gcloud run revisions list \
  --service=oute-dashboard-staging \
  --region=$GCP_REGION

# Show traffic split
gcloud run services describe oute-dashboard-staging \
  --region=$GCP_REGION \
  --format='value(status.traffic[].{revision:revision,percent:percent})'
```

### View Metrics

```bash
# View Cloud Run metrics in Cloud Console
# https://console.cloud.google.com/run/detail/$GCP_REGION/oute-dashboard-staging?project=$PROJECT_ID

# Or via Cloud Monitoring API
gcloud monitoring time-series list \
  --filter='metric.type=run.googleapis.com/request_count' \
  --format=json
```

---

## Troubleshooting

### Deployment Fails

#### Image Not Found in Artifact Registry
```bash
# Check if image was pushed
gcloud artifacts docker images list \
  ${REGISTRY}/${PROJECT_ID}/docker-repo

# Rebuild and push manually
docker build \
  --file packages/00_dashboard/Dockerfile \
  --tag oute-dashboard:local .

docker tag oute-dashboard:local \
  ${REGISTRY}/${PROJECT_ID}/docker-repo/oute-dashboard:latest

docker push ${REGISTRY}/${PROJECT_ID}/docker-repo/oute-dashboard:latest
```

#### Service Account Permission Denied
```bash
# Verify service account has required roles
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:cloud-run-sa@"

# Grant roles if missing
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cloud-run-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

#### Database Connection Failed
```bash
# Check PostgreSQL instance status
gcloud sql instances describe oute-postgres

# Check if database and user exist
gcloud sql databases list --instance=oute-postgres
gcloud sql users list --instance=oute-postgres

# Test connection from Cloud Shell (has public IP access)
gcloud sql connect oute-postgres --user=app_user

# Check SECRET_MANAGER value
gcloud secrets versions access latest --secret=DATABASE_URL

# Update if incorrect
echo "new-connection-string" | \
  gcloud secrets versions add DATABASE_URL --data-file=-
```

#### Service Not Responding (HTTP 500/502)
```bash
# Check latest logs for errors
gcloud run logs read oute-dashboard-staging \
  --region=$GCP_REGION \
  --limit=100 | grep -i error

# Check if service is still starting
gcloud run revisions list --service=oute-dashboard-staging --region=$GCP_REGION

# Check service health
curl -v https://$(gcloud run services describe oute-dashboard-staging \
  --region=$GCP_REGION \
  --format='value(status.url)' | cut -d/ -f3)

# Redeploy if needed
bash .gcp/deploy.sh dashboard staging staging-latest
```

### GitHub Actions Workflow Fails

#### Auth Failure: Invalid GCP_SA_KEY
```bash
# Verify secret is set correctly
gh secret list | grep GCP_SA_KEY

# Re-create the key
gcloud iam service-accounts keys create .gcp/keys/gh-key-new.json \
  --iam-account=github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com

# Update the GitHub secret
gh secret set GCP_SA_KEY < .gcp/keys/gh-key-new.json

# Delete old keys from GCP if needed
gcloud iam service-accounts keys list \
  --iam-account=github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com
```

#### Docker Build Fails
```bash
# Build locally to see full error
docker build \
  --file packages/00_dashboard/Dockerfile \
  . 2>&1 | tail -50

# Check Dockerfile syntax
docker build --no-cache \
  --file packages/00_dashboard/Dockerfile \
  .
```

#### Push to Artifact Registry Fails
```bash
# Verify Docker auth
docker login -u _json_key --password-stdin \
  https://${GCP_REGION}-docker.pkg.dev < .gcp/keys/gh-key.json

# Verify permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:github-actions-sa@"
```

---

## Rollback Procedures

### Rollback to Previous Revision

```bash
# View all revisions (most recent first)
gcloud run revisions list \
  --service=oute-dashboard-staging \
  --region=$GCP_REGION

# Update traffic to previous revision (100% traffic)
gcloud run services update-traffic oute-dashboard-staging \
  --region=$GCP_REGION \
  --to-revisions=<PREVIOUS_REVISION_NAME>=100

# Verify traffic was updated
gcloud run services describe oute-dashboard-staging \
  --region=$GCP_REGION \
  --format='value(status.traffic[].{revision:revision,percent:percent})'
```

### Canary Deployment (5% → 50% → 100%)

```bash
# Deploy new version
gcloud run deploy oute-dashboard-staging \
  --image=<NEW_IMAGE_URL> \
  --platform=managed \
  --region=$GCP_REGION \
  --service-account=cloud-run-sa@${PROJECT_ID}.iam.gserviceaccount.com \
  --no-traffic  # Don't route traffic yet

# Get new revision name
NEW_REVISION=$(gcloud run revisions list \
  --service=oute-dashboard-staging \
  --region=$GCP_REGION \
  --limit=1 \
  --format='value(name)')

# Old revision
OLD_REVISION=$(gcloud run revisions list \
  --service=oute-dashboard-staging \
  --region=$GCP_REGION \
  --limit=2 \
  --format='value(name)' | tail -1)

# Phase 1: 5% to new, 95% to old
gcloud run services update-traffic oute-dashboard-staging \
  --region=$GCP_REGION \
  --to-revisions=${NEW_REVISION}=5,${OLD_REVISION}=95

# Wait and monitor...
gcloud run logs read oute-dashboard-staging --region=$GCP_REGION --follow

# Phase 2: 50/50
gcloud run services update-traffic oute-dashboard-staging \
  --region=$GCP_REGION \
  --to-revisions=${NEW_REVISION}=50,${OLD_REVISION}=50

# Phase 3: 100% to new
gcloud run services update-traffic oute-dashboard-staging \
  --region=$GCP_REGION \
  --to-revisions=${NEW_REVISION}=100

# If issues, rollback
gcloud run services update-traffic oute-dashboard-staging \
  --region=$GCP_REGION \
  --to-revisions=${OLD_REVISION}=100
```

---

## Manual Deployment Workflow

Quick checklist for manual deployment:

```bash
# 1. Set variables
export PROJECT_ID="oute-app"
export GCP_REGION="us-central1"
export SERVICE="dashboard"
export ENV="staging"
export TAG="staging-latest"

# 2. Build locally
npm ci && npm run build -w 00_dashboard

# 3. Build Docker image
docker build \
  --file packages/00_dashboard/Dockerfile \
  --tag oute-${SERVICE}:local .

# 4. Tag for registry
docker tag oute-${SERVICE}:local \
  ${GCP_REGION}-docker.pkg.dev/${PROJECT_ID}/docker-repo/oute-${SERVICE}:${TAG}

# 5. Push to registry
docker push \
  ${GCP_REGION}-docker.pkg.dev/${PROJECT_ID}/docker-repo/oute-${SERVICE}:${TAG}

# 6. Deploy to Cloud Run
bash .gcp/deploy.sh $SERVICE $ENV $TAG

# 7. Test
curl https://$(gcloud run services describe oute-${SERVICE}-${ENV} \
  --region=$GCP_REGION --format='value(status.url)' | cut -d/ -f3)
```

---

## Environment Variables & Secrets

### Secrets in Secret Manager

```bash
# View secret value (with caution!)
gcloud secrets versions access latest --secret=DATABASE_URL

# Add new version (update)
echo "new-value" | gcloud secrets versions add DATABASE_URL --data-file=-

# List all versions
gcloud secrets versions list DATABASE_URL

# Destroy old version (if compromised)
gcloud secrets versions destroy VERSION_NUMBER --secret=DATABASE_URL
```

### Environment Variables in Cloud Run

Set via `--set-env-vars` during deployment:

```bash
gcloud run deploy oute-dashboard-staging \
  --set-env-vars="NODE_ENV=staging,DEBUG=false,LOG_LEVEL=info"
```

View current env vars:
```bash
gcloud run services describe oute-dashboard-staging \
  --region=$GCP_REGION \
  --format='value(spec.template.spec.containers[0].env[])'
```

---

## Cost Optimization

### Cloud Run
- **Always On**: Set minimum instances to 0 (scale to 0 when idle)
- **Memory**: Start with 256Mi for this app, increase if needed
- **CPU**: 1 CPU sufficient, increase only if CPU-bound

### Cloud SQL
- **Tier**: db-f1-micro for dev/staging, db-n1-standard-1+ for production
- **Backups**: Automatic daily, retained for 7 days
- **Unused**: Delete instances that aren't needed

### Artifact Registry
- **Retention**: Delete old images (keep only last 5-10 versions)
- **Access**: Use fine-grained IAM roles

---

## Security Best Practices

1. **Never commit secrets** to git (use .gitignore)
2. **Rotate service account keys** regularly (every 90 days)
3. **Use Cloud Armor** for DDoS protection on production
4. **Enable VPC Service Controls** to restrict data exfiltration
5. **Audit logs** regularly for unauthorized access
6. **Use custom domains** with Cloud Armor for production
7. **Implement rate limiting** at API level
8. **Encrypt data in transit** (HTTPS only)
9. **Encrypt data at rest** (Cloud SQL automatic)

---

## Additional Resources

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
- [Cloud Run Best Practices](https://cloud.google.com/run/docs/quickstarts/build-and-deploy)

---

## Support

For issues or questions:
1. Check logs: `gcloud run logs read SERVICE_NAME --region=REGION --follow`
2. Review this guide's Troubleshooting section
3. Check GCP Cloud Console for quota/billing issues
4. GitHub Actions logs available in repository Actions tab
