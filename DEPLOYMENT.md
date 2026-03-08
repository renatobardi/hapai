# Deployment Guide - GCP Cloud Run

## Overview

OUTE is deployed to **Google Cloud Platform (GCP)** using **Cloud Run** for compute, **Cloud SQL** for database, and **Artifact Registry** for container images.

Each package (00_dashboard, 01_auth-profile, 02_projects) is deployed as a separate Cloud Run service.

## Prerequisites

```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash

# Authenticate
gcloud auth login

# Set variables
export PROJECT_ID="hapai-app"
export REGION="us-central1"
```

## Phase 1: Create GCP Project

```bash
gcloud projects create $PROJECT_ID --name="OUTE App"
gcloud config set project $PROJECT_ID
```

## Phase 2: Enable APIs

```bash
gcloud services enable run.googleapis.com \
  artifactregistry.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com
```

## Phase 3: Create Artifact Registry

```bash
gcloud artifacts repositories create docker-repo \
  --repository-format=docker \
  --location=$REGION \
  --description="Docker images for OUTE"

# Configure Docker authentication
gcloud auth configure-docker $REGION-docker.pkg.dev
```

## Phase 4: Create PostgreSQL Instance

```bash
gcloud sql instances create hapai-postgres \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=$REGION \
  --storage-auto-increase \
  --backup-start-time=03:00 \
  --enable-bin-log

# Create database
gcloud sql databases create hapai_db --instance=hapai-postgres

# Create user
gcloud sql users create app-user \
  --instance=hapai-postgres \
  --password=$(openssl rand -base64 32)

# Get connection name (for Cloud Run)
gcloud sql instances describe hapai-postgres \
  --format='get(connectionName)'
```

## Phase 5: Setup Secrets

```bash
# Database URL
echo "postgresql://app-user:PASSWORD@/hapai_db?cloudSqlInstance=PROJECT:REGION:hapai-postgres" | \
  gcloud secrets create DATABASE_URL --data-file=-

# JWT Secret
openssl rand -base64 32 | gcloud secrets create JWT_SECRET --data-file=-

# Other secrets
gcloud secrets create API_KEY --data-file=-
```

## Phase 6: Create Service Accounts

**For Cloud Run:**
```bash
gcloud iam service-accounts create cloud-run-sa \
  --display-name="Cloud Run Service Account"

SA_EMAIL=$(gcloud iam service-accounts list \
  --filter="displayName=Cloud Run Service Account" \
  --format="value(email)")

# Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/secretmanager.secretAccessor"
```

**For GitHub Actions:**
```bash
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Service Account"

GH_SA=$(gcloud iam service-accounts list \
  --filter="displayName=GitHub Actions Service Account" \
  --format="value(email)")

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$GH_SA" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$GH_SA" \
  --role="roles/artifactregistry.writer"

# Create and download key
gcloud iam service-accounts keys create ~/hapai-github-key.json \
  --iam-account=$GH_SA
```

## Phase 7: Manual Deployment Test

```bash
# Build image
docker build -t hapai-dashboard:v1 packages/00_dashboard/

# Tag for Artifact Registry
docker tag hapai-dashboard:v1 \
  $REGION-docker.pkg.dev/$PROJECT_ID/docker-repo/hapai-dashboard:v1

# Push to Artifact Registry
docker push $REGION-docker.pkg.dev/$PROJECT_ID/docker-repo/hapai-dashboard:v1

# Deploy to Cloud Run
gcloud run deploy hapai-dashboard \
  --image=$REGION-docker.pkg.dev/$PROJECT_ID/docker-repo/hapai-dashboard:v1 \
  --platform=managed \
  --region=$REGION \
  --port=3000 \
  --service-account=$SA_EMAIL \
  --set-cloudsql-instances=$PROJECT_ID:$REGION:hapai-postgres \
  --set-env-vars="NODE_ENV=production" \
  --set-secrets="DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest" \
  --memory=512Mi \
  --timeout=3600s \
  --allow-unauthenticated

# Get service URL
gcloud run services describe hapai-dashboard --region=$REGION --format='value(status.url)'
```

## Phase 8: Setup GitHub Actions

Add secrets to GitHub repository:
- `GCP_PROJECT_ID=hapai-app`
- `GCP_REGION=us-central1`
- `GCP_SA_KEY=<content of ~/hapai-github-key.json>`

## Phase 9: Configure CI/CD

CI/CD workflows (in `.github/workflows/`) handle automatic deployment:

| Branch | Action |
|--------|--------|
| PR | Lint, tests, SonarQube checks |
| develop | Deploy to preview |
| staging | Deploy to homolog |
| main | Deploy to production |

## Phase 10: Monitor & Logs

```bash
# View service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=hapai-dashboard" \
  --limit 50 \
  --format json

# Describe service
gcloud run services describe hapai-dashboard --region=$REGION

# List all services
gcloud run services list --region=$REGION
```

## Environment Variables

Per-service environment variables set during deployment:

```bash
--set-env-vars="NODE_ENV=production"
--set-secrets="DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest"
```

## Rollback

If deployment fails:

```bash
# Rollback to previous revision
gcloud run services update-traffic hapai-dashboard \
  --region=$REGION \
  --to-revisions=<previous-revision>=100
```

## Custom Domain

```bash
# Map custom domain
gcloud run domain-mappings create \
  --service=hapai-dashboard \
  --domain=api.seu-dominio.com \
  --region=$REGION

# Verify status
gcloud run domain-mappings describe \
  --domain=api.seu-dominio.com \
  --region=$REGION
```

## Cost Optimization

- **Cloud Run**: Free tier = 180k CPU-seconds/month
- **Cloud SQL**: Free tier = db-f1-micro + 10 GB storage
- **Artifact Registry**: Free tier with usage limits
- **Cloud Build**: Free tier = 120 build-minutes/day

## Troubleshooting

### Service won't start
```bash
# Check logs for errors
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# Common issues:
# 1. Port not exposed (should be 3000, 3001, 3002)
# 2. Secrets not accessible
# 3. Database connection failing
```

### Cold start times too high
- Increase memory allocation (512Mi → 1Gi)
- Use Cloud Run's CPU allocation
- Pre-warm services with periodic requests

### Database connection timeout
- Ensure Cloud SQL instance is running
- Verify network connectivity
- Check credentials in Secret Manager

## Resources

- [Cloud Run Docs](https://cloud.google.com/run/docs)
- [Cloud SQL Docs](https://cloud.google.com/sql/docs)
- [Artifact Registry Docs](https://cloud.google.com/artifact-registry/docs)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)
