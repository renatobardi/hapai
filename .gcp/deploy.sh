#!/bin/bash
set -e

# OUTE Cloud Run Deployment Script
# Usage: bash .gcp/deploy.sh <service> <environment> <image_tag>
# Examples:
#   bash .gcp/deploy.sh dashboard staging staging-latest
#   bash .gcp/deploy.sh dashboard production latest
#   bash .gcp/deploy.sh auth-profile production v1.0.0

SERVICE=${1:-"dashboard"}
ENVIRONMENT=${2:-"staging"}
IMAGE_TAG=${3:-"latest"}

# Validate inputs
if [[ ! "$SERVICE" =~ ^(dashboard|auth-profile|projects)$ ]]; then
    echo "❌ Invalid service: $SERVICE"
    echo "   Valid options: dashboard, auth-profile, projects"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    echo "❌ Invalid environment: $ENVIRONMENT"
    echo "   Valid options: staging, production"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get current GCP config
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ GCP project not configured. Run:${NC}"
    echo "   gcloud config set project <project_id>"
    exit 1
fi

GCP_REGION=$(gcloud config get-value compute/region 2>/dev/null || echo "us-central1")

# Set deployment variables
REGISTRY="${GCP_REGION}-docker.pkg.dev"
IMAGE_NAME="oute-${SERVICE}"
IMAGE_URL="${REGISTRY}/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:${IMAGE_TAG}"

SERVICE_FULL_NAME="oute-${SERVICE}-${ENVIRONMENT}"
PORT=3000

SERVICE_ACCOUNT="cloud-run-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 OUTE CLOUD RUN DEPLOYMENT${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Service: $SERVICE"
echo "  Environment: $ENVIRONMENT"
echo "  Image Tag: $IMAGE_TAG"
echo "  Full Image: $IMAGE_URL"
echo "  Service Name: $SERVICE_FULL_NAME"
echo "  Project: $PROJECT_ID"
echo "  Region: $GCP_REGION"
echo ""

# Check if image exists in Artifact Registry
echo -e "${BLUE}[1/4] Verifying image exists in Artifact Registry...${NC}"
if gcloud artifacts docker images describe $IMAGE_URL >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Image found: $IMAGE_URL${NC}"
else
    echo -e "${RED}❌ Image not found: $IMAGE_URL${NC}"
    echo ""
    echo "Build and push the image first:"
    echo "  docker build --tag oute-${SERVICE}:local --file packages/*/Dockerfile ."
    echo "  docker tag oute-${SERVICE}:local $IMAGE_URL"
    echo "  docker push $IMAGE_URL"
    exit 1
fi

echo ""

# Deploy to Cloud Run
echo -e "${BLUE}[2/4] Deploying to Cloud Run...${NC}"
echo "  (This may take 1-2 minutes...)"
echo ""

gcloud run deploy $SERVICE_FULL_NAME \
    --image=$IMAGE_URL \
    --platform=managed \
    --region=$GCP_REGION \
    --service-account=${SERVICE_ACCOUNT} \
    --memory=512Mi \
    --cpu=1 \
    --timeout=3600 \
    --port=$PORT \
    --allow-unauthenticated \
    --set-env-vars="NODE_ENV=${ENVIRONMENT}" \
    --set-secrets="DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest" \
    --quiet

echo -e "${GREEN}✓ Deployment submitted${NC}"

echo ""

# Get service URL
echo -e "${BLUE}[3/4] Retrieving service URL...${NC}"
SERVICE_URL=$(gcloud run services describe $SERVICE_FULL_NAME \
    --region=$GCP_REGION \
    --format='value(status.url)')

if [ -z "$SERVICE_URL" ]; then
    echo -e "${RED}❌ Could not retrieve service URL${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Service URL: $SERVICE_URL${NC}"

echo ""

# Health check
echo -e "${BLUE}[4/4] Performing health check...${NC}"
echo "  (Waiting for service to be ready...)"

max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s -o /dev/null -w "%{http_code}" $SERVICE_URL | grep -q "200\|404"; then
        echo -e "${GREEN}✓ Service is responding (HTTP 200/404)${NC}"
        break
    fi

    attempt=$((attempt + 1))
    if [ $attempt -lt $max_attempts ]; then
        echo -n "."
        sleep 2
    fi
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${YELLOW}⚠ Health check timed out. Check logs:${NC}"
    echo "  gcloud run logs read $SERVICE_FULL_NAME --region=$GCP_REGION --follow"
else
    echo ""
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ DEPLOYMENT SUCCESSFUL!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${BLUE}📊 Deployment Summary:${NC}"
echo "  Service: $SERVICE"
echo "  Environment: $ENVIRONMENT"
echo "  Cloud Run Name: $SERVICE_FULL_NAME"
echo "  URL: $SERVICE_URL"
echo "  Region: $GCP_REGION"
echo ""

echo -e "${BLUE}🔗 Useful Commands:${NC}"
echo ""
echo "  View logs (real-time):"
echo "    gcloud run logs read $SERVICE_FULL_NAME --region=$GCP_REGION --follow"
echo ""
echo "  View service details:"
echo "    gcloud run services describe $SERVICE_FULL_NAME --region=$GCP_REGION"
echo ""
echo "  View all revisions:"
echo "    gcloud run revisions list --service=$SERVICE_FULL_NAME --region=$GCP_REGION"
echo ""
echo "  Rollback to previous revision:"
echo "    gcloud run services update-traffic $SERVICE_FULL_NAME --region=$GCP_REGION --to-revisions=<REVISION>=100"
echo ""
