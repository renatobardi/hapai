# GCP Deployment - Quick Reference

One-page cheat sheet for common GCP deployment tasks.

## Setup (First Time)

```bash
# 1. Initial infrastructure
bash .gcp/setup.sh oute-app us-central1

# 2. Create secrets
bash .gcp/create-secrets.sh

# 3. Add to GitHub (save output from step 2 first!)
gh secret set GCP_PROJECT_ID -b "oute-app"
gh secret set GCP_REGION -b "us-central1"
gh secret set GCP_SA_KEY < .gcp/keys/gh-key.json
```

## Build & Push Image

```bash
# Variables
export REGISTRY="us-central1-docker.pkg.dev"
export PROJECT="oute-app"
export IMAGE="oute-dashboard"
export TAG="staging-latest"

# Build
docker build --file packages/00_dashboard/Dockerfile --tag $IMAGE:local .

# Tag
docker tag $IMAGE:local $REGISTRY/$PROJECT/docker-repo/$IMAGE:$TAG

# Push
docker push $REGISTRY/$PROJECT/docker-repo/$IMAGE:$TAG
```

## Deploy to Cloud Run

```bash
# Staging (using script - recommended)
bash .gcp/deploy.sh dashboard staging staging-latest

# Production
bash .gcp/deploy.sh dashboard production v1.0.0

# Get URL
gcloud run services describe oute-dashboard-staging --region=us-central1 --format='value(status.url)'
```

## View Logs

```bash
# Last 50 lines (staging)
gcloud run logs read oute-dashboard-staging --region=us-central1 --limit=50

# Real-time (staging)
gcloud run logs read oute-dashboard-staging --region=us-central1 --follow

# Search for errors
gcloud run logs read oute-dashboard-staging --region=us-central1 | grep -i error

# Production
gcloud run logs read oute-dashboard --region=us-central1 --follow
```

## Revisions & Rollback

```bash
# View all revisions (staging)
gcloud run revisions list --service=oute-dashboard-staging --region=us-central1

# Rollback to previous (staging)
gcloud run services update-traffic oute-dashboard-staging \
  --region=us-central1 \
  --to-revisions=<REVISION_NAME>=100

# Canary: 10% new, 90% old
gcloud run services update-traffic oute-dashboard-staging \
  --region=us-central1 \
  --to-revisions=<NEW_REVISION>=10,<OLD_REVISION>=90
```

## Secrets Management

```bash
# View secret value
gcloud secrets versions access latest --secret=DATABASE_URL

# Update secret
echo "new-value" | gcloud secrets versions add DATABASE_URL --data-file=-

# List all secrets
gcloud secrets list

# List secret versions
gcloud secrets versions list DATABASE_URL
```

## GitHub Actions

```bash
# List workflows
gh workflow list

# Trigger manual deploy
gh workflow run deploy-staging-manual.yml -f service=dashboard -f image_tag=staging-latest

# View workflow runs
gh run list --workflow=deploy-on-staging-branch.yml

# View logs for specific run
gh run view <RUN_ID> --log
```

## Databases

```bash
# Check PostgreSQL status
gcloud sql instances describe oute-postgres

# List databases
gcloud sql databases list --instance=oute-postgres

# List users
gcloud sql users list --instance=oute-postgres

# Connect from Cloud Shell
gcloud sql connect oute-postgres --user=app_user
```

## Service Accounts

```bash
# List service accounts
gcloud iam service-accounts list

# Show Cloud Run SA roles
gcloud projects get-iam-policy oute-app \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:cloud-run-sa@"

# Create new service account key (if needed)
gcloud iam service-accounts keys create .gcp/keys/gh-key-new.json \
  --iam-account=github-actions-sa@oute-app.iam.gserviceaccount.com
```

## Artifact Registry

```bash
# List images
gcloud artifacts docker images list us-central1-docker.pkg.dev/oute-app/docker-repo

# Show image details
gcloud artifacts docker images describe \
  us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest

# List image tags
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard
```

## Monitoring

```bash
# Cloud Run service details
gcloud run services describe oute-dashboard-staging --region=us-central1

# View current traffic split
gcloud run services describe oute-dashboard-staging \
  --region=us-central1 \
  --format='value(status.traffic[].{revision:revision,percent:percent})'

# View resource usage
gcloud run services describe oute-dashboard-staging \
  --region=us-central1 \
  --format='value(spec.template.spec.containers[0].resources)'
```

## Project Configuration

```bash
# Set default project
gcloud config set project oute-app

# Set default region
gcloud config set compute/region us-central1

# View current configuration
gcloud config list

# Verify APIs enabled
gcloud services list --enabled | grep -E "run|artifact|sql|secret"
```

## Common One-Liners

```bash
# Deploy staging + show URL
bash .gcp/deploy.sh dashboard staging staging-latest && \
gcloud run services describe oute-dashboard-staging --region=us-central1 --format='value(status.url)'

# Tail logs while deploying
bash .gcp/deploy.sh dashboard staging staging-latest & \
gcloud run logs read oute-dashboard-staging --region=us-central1 --follow

# Build image in one go
docker build --file packages/00_dashboard/Dockerfile --tag oute-dashboard:local . && \
docker tag oute-dashboard:local us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest && \
docker push us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest

# List all services
gcloud run services list --region=us-central1 --format='value(name,status.url)'

# Check which revision is active
gcloud run services describe oute-dashboard-staging --region=us-central1 --format='value(status.traffic[0].revision)'
```

## Environment Variables

**Set during deployment:**
```bash
gcloud run deploy oute-dashboard-staging \
  --set-env-vars="NODE_ENV=staging,DEBUG=false,LOG_LEVEL=info"
```

**View current:**
```bash
gcloud run services describe oute-dashboard-staging --region=us-central1 \
  --format='value(spec.template.spec.containers[0].env[].{name:name,value:value})'
```

## Troubleshooting One-Liners

```bash
# Check if image exists
gcloud artifacts docker images describe us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest

# Verify service account permissions
gcloud projects get-iam-policy oute-app --flatten="bindings[].members" --filter="bindings.members:cloud-run-sa@"

# Check Cloud SQL instance status
gcloud sql instances describe oute-postgres

# View service events
gcloud run services describe oute-dashboard-staging --region=us-central1 --format=json | jq '.status'

# Redeploy latest image
gcloud run deploy oute-dashboard-staging --image=us-central1-docker.pkg.dev/oute-app/docker-repo/oute-dashboard:staging-latest --platform=managed --region=us-central1
```

## GitHub Secrets

```bash
# Add/update secrets
gh secret set GCP_PROJECT_ID -b "oute-app"
gh secret set GCP_REGION -b "us-central1"
gh secret set GCP_SA_KEY < .gcp/keys/gh-key.json

# List secrets
gh secret list

# View actions/workflow files
gh api repos/renatobardi/oute-main/contents/.github/workflows --paginate
```

---

**For full details, see:**
- `.gcp/README.md` - Script documentation
- `GCP-DEPLOYMENT.md` - Complete deployment guide
- `gcloud --help` - GCP CLI reference
