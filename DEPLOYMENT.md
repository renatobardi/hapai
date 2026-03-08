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
export PROJECT_ID="oute-app"
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
gcloud sql instances create oute-postgres \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=$REGION \
  --storage-auto-increase \
  --backup-start-time=03:00 \
  --enable-bin-log

# Create database
gcloud sql databases create oute_db --instance=oute-postgres

# Create user
gcloud sql users create app-user \
  --instance=oute-postgres \
  --password=$(openssl rand -base64 32)

# Get connection name (for Cloud Run)
gcloud sql instances describe oute-postgres \
  --format='get(connectionName)'
```

## Phase 5: Setup Secrets

```bash
# Database URL
echo "postgresql://app-user:PASSWORD@/oute_db?cloudSqlInstance=PROJECT:REGION:oute-postgres" | \
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
gcloud iam service-accounts keys create ~/oute-github-key.json \
  --iam-account=$GH_SA
```

## Phase 7: Manual Deployment Test

```bash
# Build image
docker build -t oute-dashboard:v1 packages/00_dashboard/

# Tag for Artifact Registry
docker tag oute-dashboard:v1 \
  $REGION-docker.pkg.dev/$PROJECT_ID/docker-repo/oute-dashboard:v1

# Push to Artifact Registry
docker push $REGION-docker.pkg.dev/$PROJECT_ID/docker-repo/oute-dashboard:v1

# Deploy to Cloud Run
gcloud run deploy oute-dashboard \
  --image=$REGION-docker.pkg.dev/$PROJECT_ID/docker-repo/oute-dashboard:v1 \
  --platform=managed \
  --region=$REGION \
  --port=3000 \
  --service-account=$SA_EMAIL \
  --set-cloudsql-instances=$PROJECT_ID:$REGION:oute-postgres \
  --set-env-vars="NODE_ENV=production" \
  --set-secrets="DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest" \
  --memory=512Mi \
  --timeout=3600s \
  --allow-unauthenticated

# Get service URL
gcloud run services describe oute-dashboard --region=$REGION --format='value(status.url)'
```

## Phase 8: Setup GitHub Actions

Add secrets to GitHub repository:
- `GCP_PROJECT_ID=oute-app`
- `GCP_REGION=us-central1`
- `GCP_SA_KEY=<content of ~/oute-github-key.json>`

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
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=oute-dashboard" \
  --limit 50 \
  --format json

# Describe service
gcloud run services describe oute-dashboard --region=$REGION

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
gcloud run services update-traffic oute-dashboard \
  --region=$REGION \
  --to-revisions=<previous-revision>=100
```

## Custom Domain

```bash
# Map custom domain
gcloud run domain-mappings create \
  --service=oute-dashboard \
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

## ✅ Automated CI/CD Pipeline (GitHub Actions)

O pipeline automático foi completamente configurado e testado. Toda vez que você faz push para `main`, a seguinte sequência ocorre automaticamente:

### Workflow Sequencial (Sem Conflitos)

```yaml
1. build-and-test (1-2 minutos)
   ├─ Checkout code
   ├─ Setup Node.js 20
   ├─ Install dependencies
   ├─ Run linter
   └─ Build dashboard package

2. deploy-production (3-5 minutos) [após build-and-test]
   ├─ Authenticate with GCP (Workload Identity)
   ├─ Setup Cloud SDK
   ├─ Configure Docker for Artifact Registry
   ├─ Build multi-stage Docker image
   ├─ Push to Artifact Registry (3 tags)
   ├─ Deploy to Cloud Run
   ├─ Run health checks
   ├─ Create GitHub deployment record
   ├─ Update deployment status
   ├─ Create GitHub release
   └─ Generate deployment summary
```

### Permissions Necessárias

```yaml
deploy-production:
  permissions:
    contents: write        # Create releases
    id-token: write       # GCP Workload Identity Federation
    deployments: write    # Track deployments
    statuses: write       # Update commit status
```

### Workload Identity Federation (WIF)

O pipeline usa **WIF** em vez de service account keys (mais seguro):
- GitHub gera um token JWT assinado
- GCP valida o token sem chaves armazenadas
- Acesso temporário e auditável

### Rastreamento de Deployments

Cada deployment é registrado no GitHub:
```bash
# Ver deployments
gh deployment list --repo renatobardi/oute-main

# Ver status de um deployment
gh deployment view <deployment-id>
```

### Monitorar Execução

```bash
# Ver workflow runs
gh run list --repo renatobardi/oute-main --branch main

# Ver logs completos
gh run view <run-id> --log

# Ver apenas erros
gh run view <run-id> --log-failed
```

### Rollback Automático

Se o health check falhar, o deployment é automaticamente revertido para a revision anterior.

### Exemplo: Deploy em Produção

```bash
# 1. Faça mudanças e commit em uma branch
git checkout -b feature/nova-funcao
# ... mudanças ...
git commit -m "feat: nova funcionalidade"

# 2. Faça push e crie PR para develop
git push origin feature/nova-funcao
# (Abrir PR no GitHub)

# 3. Após aprovação, merge para main
# (O workflow automático é disparado)

# 4. Ver progresso
gh run list --repo renatobardi/oute-main --branch main --limit 1

# 5. Ver logs em tempo real
gh run view <run-id> --log

# 6. Após sucesso, acessar em produção
https://oute-dashboard-kx25r3idia-uc.a.run.app
```

### Cloud Run Service URLs

- **Dashboard**: https://oute-dashboard-kx25r3idia-uc.a.run.app

### Problemas Comuns

**Pipeline falhando?**
1. Verificar logs: `gh run view <id> --log`
2. Procurar por "Error" nas anotações
3. Causas comuns:
   - Lint errors (rodar `npm run lint` localmente)
   - Build failures (rodar `npm run build` localmente)
   - Permission issues (verificar GCP IAM)

**Health check falhando?**
1. Verificar se service está rodando: `gcloud run services describe oute-dashboard`
2. Ver logs: `gcloud run logs read oute-dashboard --follow`
3. Testar endpoint: `curl https://oute-dashboard-kx25r3idia-uc.a.run.app`

**Docker image muito grande?**
- Verifique o Dockerfile multi-stage
- Confirme que apenas `dist/` é copiado
- Remova arquivos desnecessários

## Resources

- [Cloud Run Docs](https://cloud.google.com/run/docs)
- [Cloud SQL Docs](https://cloud.google.com/sql/docs)
- [Artifact Registry Docs](https://cloud.google.com/artifact-registry/docs)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Workload Identity Federation](https://cloud.google.com/docs/authentication/workload-identity-federation)
