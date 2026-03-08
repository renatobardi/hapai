#!/bin/bash
set -e

# OUTE GCP Setup Script - Complete Infrastructure Setup
# Usage: bash .gcp/setup.sh <project_id> <region> <billing_account_id>
# Example: bash .gcp/setup.sh oute-app us-central1 01ABCD-EF1234-GH5678

PROJECT_ID=${1:-"oute-app"}
GCP_REGION=${2:-"us-central1"}
BILLING_ACCOUNT_ID=${3:-""}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 OUTE GCP SETUP - Complete Infrastructure${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $GCP_REGION"
echo "  Billing Account: ${BILLING_ACCOUNT_ID:-'(will prompt if needed)'}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}✗ gcloud CLI not found. Install it first:${NC}"
    echo "  https://cloud.google.com/sdk/docs/install"
    exit 1
fi

echo -e "${GREEN}✓ gcloud CLI found${NC}"
echo ""

# 1. Create and configure project
echo -e "${BLUE}[1/6] Creating GCP Project...${NC}"
if gcloud projects create $PROJECT_ID --name="OUTE App" 2>/dev/null; then
    echo -e "${GREEN}✓ Project created${NC}"
else
    echo -e "${YELLOW}ℹ Project already exists${NC}"
fi

gcloud config set project $PROJECT_ID
echo -e "${GREEN}✓ Project set as default${NC}"

# Link billing account if provided
if [ -n "$BILLING_ACCOUNT_ID" ]; then
    echo -e "${BLUE}[1/6] Linking Billing Account...${NC}"
    gcloud billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT_ID
    echo -e "${GREEN}✓ Billing account linked${NC}"
else
    echo -e "${YELLOW}ℹ Billing account not provided (skip for now)${NC}"
fi

echo ""

# 2. Enable required APIs
echo -e "${BLUE}[2/6] Enabling Required APIs...${NC}"
gcloud services enable \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    sqladmin.googleapis.com \
    secretmanager.googleapis.com \
    cloudbuild.googleapis.com \
    containerregistry.googleapis.com \
    compute.googleapis.com \
    iam.googleapis.com

echo -e "${GREEN}✓ All APIs enabled${NC}"
echo ""

# 3. Create Artifact Registry
echo -e "${BLUE}[3/6] Setting up Artifact Registry...${NC}"
if gcloud artifacts repositories create docker-repo \
    --repository-format=docker \
    --location=$GCP_REGION \
    --description="OUTE Docker images" 2>/dev/null; then
    echo -e "${GREEN}✓ Docker repository created${NC}"
else
    echo -e "${YELLOW}ℹ Docker repository already exists${NC}"
fi

gcloud auth configure-docker ${GCP_REGION}-docker.pkg.dev
echo -e "${GREEN}✓ Docker auth configured${NC}"

echo ""

# 4. Create Cloud SQL PostgreSQL Instance
echo -e "${BLUE}[4/6] Creating Cloud SQL PostgreSQL Instance...${NC}"
if gcloud sql instances create oute-postgres \
    --database-version=POSTGRES_15 \
    --tier=db-f1-micro \
    --region=$GCP_REGION \
    --network=default \
    --backup-start-time=03:00 \
    --retained-backups-count=7 \
    --transaction-log-retention-days=7 \
    --storage-type=SSD \
    --storage-size=10GB 2>/dev/null; then
    echo -e "${GREEN}✓ PostgreSQL instance created${NC}"
    echo -e "${YELLOW}  (Waiting ~5 minutes for instance to be ready...)${NC}"
    sleep 10
else
    echo -e "${YELLOW}ℹ PostgreSQL instance already exists${NC}"
fi

# Get instance connection name
CONNECTION_NAME=$(gcloud sql instances describe oute-postgres --format="value(connectionName)")
echo -e "${GREEN}✓ Instance connection name: $CONNECTION_NAME${NC}"

echo -e "${BLUE}  Creating database and user...${NC}"

# Create database
if gcloud sql databases create oute_db \
    --instance=oute-postgres \
    --charset=UTF8 2>/dev/null; then
    echo -e "${GREEN}  ✓ Database 'oute_db' created${NC}"
else
    echo -e "${YELLOW}  ℹ Database 'oute_db' already exists${NC}"
fi

# Create app user
if gcloud sql users create app_user \
    --instance=oute-postgres \
    --password 2>/dev/null; then
    echo -e "${GREEN}  ✓ User 'app_user' created${NC}"
else
    echo -e "${YELLOW}  ℹ User 'app_user' already exists${NC}"
fi

echo ""

# 5. Create Service Accounts
echo -e "${BLUE}[5/6] Creating Service Accounts...${NC}"

# Cloud Run Service Account
if gcloud iam service-accounts create cloud-run-sa \
    --display-name="OUTE Cloud Run Service Account" 2>/dev/null; then
    echo -e "${GREEN}✓ Cloud Run service account created${NC}"
else
    echo -e "${YELLOW}ℹ Cloud Run service account already exists${NC}"
fi

SERVICE_ACCOUNT="cloud-run-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant roles to Cloud Run SA
echo -e "${BLUE}  Granting roles to Cloud Run service account...${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/cloudsql.client" \
    --condition=None >/dev/null 2>&1 || true

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/secretmanager.secretAccessor" \
    --condition=None >/dev/null 2>&1 || true

echo -e "${GREEN}  ✓ Cloud Run SA roles configured${NC}"

# GitHub Actions Service Account
if gcloud iam service-accounts create github-actions-sa \
    --display-name="GitHub Actions CI/CD" 2>/dev/null; then
    echo -e "${GREEN}✓ GitHub Actions service account created${NC}"
else
    echo -e "${YELLOW}ℹ GitHub Actions service account already exists${NC}"
fi

GH_SA="github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant roles to GitHub Actions SA
echo -e "${BLUE}  Granting roles to GitHub Actions service account...${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GH_SA}" \
    --role="roles/run.admin" \
    --condition=None >/dev/null 2>&1 || true

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GH_SA}" \
    --role="roles/artifactregistry.writer" \
    --condition=None >/dev/null 2>&1 || true

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GH_SA}" \
    --role="roles/secretmanager.secretAccessor" \
    --condition=None >/dev/null 2>&1 || true

echo -e "${GREEN}  ✓ GitHub Actions SA roles configured${NC}"

echo ""

# 6. Create service account keys
echo -e "${BLUE}[6/6] Creating Service Account Keys...${NC}"

KEY_DIR=".gcp/keys"
mkdir -p $KEY_DIR

if [ ! -f "$KEY_DIR/gh-key.json" ]; then
    gcloud iam service-accounts keys create $KEY_DIR/gh-key.json \
        --iam-account=${GH_SA}
    echo -e "${GREEN}✓ GitHub Actions key created at: $KEY_DIR/gh-key.json${NC}"
    echo -e "${YELLOW}  ⚠️  IMPORTANT: Store this key securely!${NC}"
else
    echo -e "${YELLOW}ℹ GitHub Actions key already exists${NC}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ GCP SETUP COMPLETE!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${BLUE}📋 Next Steps:${NC}"
echo ""
echo "1. Create secrets in Secret Manager:"
echo "   bash .gcp/create-secrets.sh"
echo ""
echo "2. Add GitHub secrets:"
echo "   gh secret set GCP_PROJECT_ID -b \"$PROJECT_ID\""
echo "   gh secret set GCP_REGION -b \"$GCP_REGION\""
echo "   gh secret set GCP_SA_KEY < $KEY_DIR/gh-key.json"
echo ""
echo "3. Build and test dashboard locally:"
echo "   npm ci && npm run build -w 00_dashboard"
echo ""
echo "4. Deploy to staging:"
echo "   bash .gcp/deploy.sh dashboard staging staging-latest"
echo ""
echo "5. Review logs:"
echo "   gcloud run logs read oute-dashboard-staging --region=$GCP_REGION --follow"
echo ""

echo -e "${YELLOW}📊 Infrastructure Summary:${NC}"
echo "  Project: $PROJECT_ID"
echo "  Region: $GCP_REGION"
echo "  PostgreSQL: oute-postgres ($CONNECTION_NAME)"
echo "  Cloud Run SA: $SERVICE_ACCOUNT"
echo "  GitHub Actions SA: $GH_SA"
echo "  Docker Registry: ${GCP_REGION}-docker.pkg.dev/$PROJECT_ID/docker-repo"
echo ""
