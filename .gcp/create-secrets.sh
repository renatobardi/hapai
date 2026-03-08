#!/bin/bash
set -e

# OUTE Secret Manager Setup Script
# Creates required secrets for Cloud Run deployments

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔐 OUTE SECRET MANAGER SETUP${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get current GCP config
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ GCP project not configured. Run:${NC}"
    echo "   gcloud config set project <project_id>"
    exit 1
fi

GCP_REGION=$(gcloud config get-value compute/region 2>/dev/null || echo "us-central1")

echo -e "${YELLOW}Configuration:${NC}"
echo "  Project: $PROJECT_ID"
echo "  Region: $GCP_REGION"
echo ""

# Generate secure values
echo -e "${BLUE}[1/3] Generating secure values...${NC}"

DB_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 32)
API_KEY=$(openssl rand -base64 32)

echo -e "${GREEN}✓ Generated secure random values${NC}"
echo ""

# Create DATABASE_URL secret
echo -e "${BLUE}[2/3] Creating DATABASE_URL secret...${NC}"

DB_CONNECTION_NAME="oute-postgres"  # Will be updated with actual format after SQL instance is created

# Get actual connection name if instance exists
if gcloud sql instances describe oute-postgres >/dev/null 2>&1; then
    DB_CONNECTION_NAME=$(gcloud sql instances describe oute-postgres --format="value(connectionName)")
    echo -e "${GREEN}✓ Found PostgreSQL instance: $DB_CONNECTION_NAME${NC}"
else
    echo -e "${YELLOW}⚠ PostgreSQL instance not found yet. Using placeholder.${NC}"
    echo "  After PostgreSQL is created, update DATABASE_URL in Secret Manager"
    DB_CONNECTION_NAME="PROJECT:REGION:oute-postgres"
fi

DATABASE_URL="postgresql://app_user:${DB_PASSWORD}@/oute_db?cloudSqlInstance=${DB_CONNECTION_NAME}&user=app_user&password=${DB_PASSWORD}"

if gcloud secrets describe DATABASE_URL >/dev/null 2>&1; then
    echo "  Updating existing DATABASE_URL secret..."
    echo -n "$DATABASE_URL" | gcloud secrets versions add DATABASE_URL --data-file=-
    echo -e "${GREEN}✓ DATABASE_URL updated${NC}"
else
    echo "  Creating new DATABASE_URL secret..."
    echo -n "$DATABASE_URL" | gcloud secrets create DATABASE_URL \
        --data-file=- \
        --replication-policy="automatic"
    echo -e "${GREEN}✓ DATABASE_URL created${NC}"
fi

echo ""

# Create JWT_SECRET
echo -e "${BLUE}[3/3] Creating JWT_SECRET...${NC}"

if gcloud secrets describe JWT_SECRET >/dev/null 2>&1; then
    echo "  Updating existing JWT_SECRET..."
    echo -n "$JWT_SECRET" | gcloud secrets versions add JWT_SECRET --data-file=-
    echo -e "${GREEN}✓ JWT_SECRET updated${NC}"
else
    echo "  Creating new JWT_SECRET..."
    echo -n "$JWT_SECRET" | gcloud secrets create JWT_SECRET \
        --data-file=- \
        --replication-policy="automatic"
    echo -e "${GREEN}✓ JWT_SECRET created${NC}"
fi

echo ""

# List created secrets
echo -e "${BLUE}Verifying secrets...${NC}"
gcloud secrets list

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SECRETS CREATED SUCCESSFULLY!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}📝 Secret Values (save in secure location):${NC}"
echo ""
echo "  DATABASE_URL (Connection String):"
echo "    $DATABASE_URL"
echo ""
echo "  JWT_SECRET:"
echo "    $JWT_SECRET"
echo ""
echo "  API_KEY (for future use):"
echo "    $API_KEY"
echo ""

echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
echo "  1. Save these values in a secure location (password manager, vault)"
echo "  2. Do NOT commit these values to git"
echo "  3. If DATABASE_URL above shows 'PROJECT:REGION' placeholder,"
echo "     run this script again after PostgreSQL instance is fully ready"
echo ""

echo -e "${BLUE}🔗 Useful Commands:${NC}"
echo ""
echo "  View secret value:"
echo "    gcloud secrets versions access latest --secret=DATABASE_URL"
echo ""
echo "  Update secret:"
echo "    echo 'new-value' | gcloud secrets versions add DATABASE_URL --data-file=-"
echo ""
echo "  List all secrets:"
echo "    gcloud secrets list"
echo ""
