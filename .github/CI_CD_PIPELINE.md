# CI/CD Pipeline Documentation

## Overview

O pipeline de CI/CD automatiza todo o processo de build, test e deployment para GCP Cloud Run. O pipeline é configurado como **sequential** (não paralelo) para evitar conflitos e garantir ordem de execução correta.

## Pipeline Architecture

```
┌─────────────┐
│ Push para   │
│   main      │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│  Job 1: build-and-test              │
│  ─────────────────────────────────  │
│  ✓ Checkout code                    │
│  ✓ Setup Node.js 20                 │
│  ✓ Install dependencies             │
│  ✓ Run ESLint                       │
│  ✓ Build dashboard package          │
│  ✓ Upload build artifacts (dist/)   │
└──────┬──────────────────────────────┘
       │ (Duração: ~2 minutos)
       ▼ (depende de: build-and-test)
┌─────────────────────────────────────┐
│  Job 2: deploy-production           │
│  ─────────────────────────────────  │
│  ✓ Checkout code                    │
│  ✓ GCP Authentication (WIF)         │
│  ✓ Setup Cloud SDK                  │
│  ✓ Configure Docker                 │
│  ✓ Build Docker image               │
│  ✓ Push to Artifact Registry        │
│  ✓ Deploy to Cloud Run              │
│  ✓ Health checks                    │
│  ✓ Create GitHub deployment         │
│  ✓ Create release                   │
└──────┬──────────────────────────────┘
       │ (Duração: ~5 minutos)
       ▼
    SUCCESS ✅ ou FAILURE ❌
```

## Workflow Configuration

### File Location
`.github/workflows/deploy-on-main-branch.yml`

### Key Settings

```yaml
name: Auto Deploy on Main Branch Push (Production)

on:
  push:
    branches:
      - main

concurrency:
  group: production-deployment
  cancel-in-progress: false  # Sequential, não paralelo
```

### Job Dependencies

```yaml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

  deploy-production:
    needs: build-and-test  # ← Aguarda build-and-test terminar
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: write      # Criar releases
      id-token: write      # GCP Workload Identity
      deployments: write   # Rastrear deployments
      statuses: write      # Atualizar status
```

## Build Job Detalhes

### 1. Checkout Code
```bash
uses: actions/checkout@v4
```
Clona o repositório completo.

### 2. Setup Node.js
```bash
uses: actions/setup-node@v4
with:
  node-version: '20'
```
Instala Node.js v20 (LTS).

### 3. Install Dependencies
```bash
npm ci --legacy-peer-deps
```
- `npm ci` = Clean install (mais seguro que `npm install`)
- `--legacy-peer-deps` = Permite peerDependencies antigas

### 4. Lint Check
```bash
npm run lint
```
Executa ESLint em todo o código.

**Falha se:**
- Há erros de linting
- Há `any` types não documentados
- Há imports não utilizados

### 5. Build Dashboard
```bash
npm run build -w oute-dashboard
```
- `-w oute-dashboard` = Build apenas do workspace "oute-dashboard"
- Output: `packages/00_dashboard/dist/`

## Deploy Job Detalhes

### 1. GCP Authentication (Workload Identity Federation)

```bash
uses: google-github-actions/auth@v2
with:
  workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
  service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

**Vantagens do WIF:**
- ✅ Sem necessidade de service account keys
- ✅ Tokens temporários
- ✅ Totalmente auditável
- ✅ Mais seguro

### 2. Setup Cloud SDK
```bash
uses: google-github-actions/setup-gcloud@v2
```
Instala Google Cloud SDK (`gcloud` CLI).

### 3. Configure Docker
```bash
gcloud auth configure-docker ${{ env.REGISTRY }}
```
Configura autenticação do Docker com Artifact Registry.

### 4. Build Docker Image

```bash
docker build \
  --file packages/00_dashboard/Dockerfile \
  --tag $REGISTRY/$PROJECT_ID/docker-repo/$IMAGE_NAME:latest \
  --tag $REGISTRY/$PROJECT_ID/docker-repo/$IMAGE_NAME:v${{ github.run_number }} \
  --tag $REGISTRY/$PROJECT_ID/docker-repo/$IMAGE_NAME:${{ github.sha }} \
  .
```

**Tags:**
- `latest` = Versão mais recente
- `v12` = Build number
- `27a6099...` = Commit SHA (identificação única)

### 5. Push para Artifact Registry

```bash
docker push $REGISTRY/$PROJECT_ID/docker-repo/$IMAGE_NAME:latest
docker push $REGISTRY/$PROJECT_ID/docker-repo/$IMAGE_NAME:v12
docker push $REGISTRY/$PROJECT_ID/docker-repo/$IMAGE_NAME:27a6099...
```

### 6. Deploy para Cloud Run

```bash
gcloud run deploy "oute-dashboard" \
  --image="$IMAGE_URL" \
  --platform=managed \
  --region=$GCP_REGION \
  --service-account=cloud-run-sa@$PROJECT_ID.iam.gserviceaccount.com \
  --memory=512Mi \
  --cpu=1 \
  --timeout=3600 \
  --port=3000 \
  --allow-unauthenticated \
  --set-env-vars="NODE_ENV=production" \
  --set-secrets="DATABASE_URL=DATABASE_URL:latest,JWT_SECRET=JWT_SECRET:latest" \
  --quiet
```

**Configurações:**
- Memory: 512Mi (suficiente para dashboard)
- CPU: 1 vCPU
- Timeout: 1 hora (uploads/processamento)
- Port: 3000 (definido no Dockerfile)
- Sem autenticação (público)

### 7. Health Check

```bash
for i in {1..30}; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
  if [[ "$HTTP_CODE" =~ ^(200|404)$ ]]; then
    echo "✅ Production service is responding"
    exit 0
  fi
  sleep 2
done
```

**O que verifica:**
- Tenta 30 vezes com 2 segundos de intervalo
- Aceita HTTP 200 (OK) ou 404 (página não encontrada)
- Falha se serviço não responder

### 8. Create GitHub Deployment

```bash
uses: chrnorm/deployment-action@v2
with:
  token: ${{ secrets.GITHUB_TOKEN }}
  environment: production
  description: 'Production deployment of OUTE Dashboard v12'
```

Cria um record de deployment no GitHub para rastreamento.

### 9. Create Release

```bash
uses: ncipollo/release-action@v1
with:
  tag: v${{ github.run_number }}
  name: Release v${{ github.run_number }}
  body: |
    ## Production Deployment v12

    **Service:** OUTE Dashboard
    **Commit:** 27a6099ec770...
    **Author:** renatobardi
    **Image Tags:**
    - latest
    - v12
    - 27a6099...

    **Service URL:** https://oute-dashboard-kx25r3idia-uc.a.run.app
```

Cria uma release no GitHub com informações sobre o deployment.

## Environment Variables

```yaml
env:
  GCP_PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  GCP_REGION: ${{ secrets.GCP_REGION }}
  REGISTRY: ${{ secrets.GCP_REGION }}-docker.pkg.dev
  IMAGE_NAME: oute-dashboard
```

## Secrets Necessários

```bash
# GitHub repository secrets
GCP_PROJECT_ID           # oute-main
GCP_REGION               # us-central1
GCP_WORKLOAD_IDENTITY_PROVIDER  # projects/123456/locations/global/workloadIdentityPools/...
GCP_SERVICE_ACCOUNT      # github-actions-sa@oute-main.iam.gserviceaccount.com
GITHUB_TOKEN            # Automático (gerado pelo Actions)
```

## Error Handling

### Se Lint Falhar
```bash
# Localmente, rodar:
npm run lint

# Corrigir erros
npm run format

# Commit e push
```

### Se Build Falhar
```bash
# Verificar localmente:
npm run build -w oute-dashboard

# Se houver erro de módulo:
rm -rf node_modules package-lock.json
npm install --legacy-peer-deps
npm run build -w oute-dashboard
```

### Se Deploy Falhar
1. Ver logs: `gh run view <id> --log`
2. Procurar por "Error" ou "Permission denied"
3. Causas comuns:
   - Image não pode ser pulled
   - Service account sem permissão
   - Secret não encontrado
   - Health check timeout

### Se Rollback for Necessário
```bash
# Listar revisions
gcloud run revisions list \
  --service=oute-dashboard \
  --region=us-central1

# Reverter para revision anterior
gcloud run services update-traffic oute-dashboard \
  --region=us-central1 \
  --to-revisions=oute-dashboard-00001-5ft=100
```

## Monitorando o Pipeline

### No GitHub
```bash
# Ver últimos workflows
gh run list --repo renatobardi/oute-main --limit 5

# Ver logs de um workflow
gh run view <run-id> --log

# Ver apenas erros
gh run view <run-id> --log-failed

# Aguardar conclusão
gh run watch <run-id>
```

### No GCP
```bash
# Ver service
gcloud run services describe oute-dashboard --region=us-central1

# Ver logs
gcloud run logs read oute-dashboard --region=us-central1 --follow

# Ver revisions
gcloud run revisions list --service=oute-dashboard --region=us-central1

# Ver métricas
gcloud monitoring metrics-descriptors list --filter="metric.type:run.googleapis.com"
```

## Performance Benchmarks

| Step | Duração Típica |
|------|---|
| Checkout | 5s |
| Setup Node.js | 10s |
| Install deps | 60s |
| Lint | 15s |
| Build | 30s |
| Upload artifacts | 5s |
| **build-and-test total** | **~2 minutos** |
| | |
| GCP Auth | 3s |
| Setup Cloud SDK | 20s |
| Docker build | 10s |
| Docker push | 10s |
| Cloud Run deploy | 30s |
| Health checks | 5s |
| Create release | 3s |
| **deploy-production total** | **~3-5 minutos** |
| | |
| **Total Pipeline** | **~5-7 minutos** |

## Best Practices

1. **Sempre rodar testes localmente** antes de push
   ```bash
   npm run lint
   npm run build
   npm run test
   ```

2. **Fazer commits atômicos** com mensagens descritivas
   ```bash
   git commit -m "feat: novo recurso"
   git commit -m "fix: corrigir bug"
   git commit -m "docs: atualizar documentação"
   ```

3. **Verificar logs do workflow** se algo falhar
   ```bash
   gh run view <id> --log
   ```

4. **Usar feature branches** antes de fazer push para main
   ```bash
   git checkout -b feature/nova-coisa
   # ... fazer mudanças ...
   git push origin feature/nova-coisa
   # Criar PR no GitHub
   ```

5. **Monitorar serviço após deploy**
   ```bash
   gcloud run logs read oute-dashboard --follow
   ```

## Troubleshooting Checklist

- [ ] Código faz lint sem erros (`npm run lint`)
- [ ] Build funciona localmente (`npm run build`)
- [ ] Testes passam (`npm run test`)
- [ ] Commit message segue padrão (`type(scope): description`)
- [ ] PR foi aprovado antes do merge
- [ ] Secrets estão configurados no GitHub
- [ ] GCP service accounts têm permissões corretas
- [ ] Docker image é pequena (< 500MB)
- [ ] Dockerfile usa multi-stage build
- [ ] Health check endpoint responde com 200/404
