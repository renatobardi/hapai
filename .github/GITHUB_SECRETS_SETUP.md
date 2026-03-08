# GitHub Secrets Setup Guide

Configure estes secrets no repositório GitHub para que os workflows funcionem.

## 1. GCP Secrets

Após executar o script GCP (setup-gcp.sh), adicione em **Settings → Secrets and variables → Actions**:

### GCP_SA_KEY
- **Valor**: Conteúdo do arquivo `~/oute-github-key.json`
- **Usar para**: GitHub Actions fazer deploy em Cloud Run
- **Como obter**:
  ```bash
  cat ~/oute-github-key.json
  # Copie todo o conteúdo JSON
  ```

### GCP_PROJECT_ID
- **Valor**: `oute-app` (ou seu project ID)
- **Usar para**: Identificar projeto GCP nos workflows

### GCP_REGION
- **Valor**: `us-central1` (ou sua região preferida)
- **Usar para**: Deploy region no Cloud Run

## 2. Artifact Registry

Após criar repo npm em Artifact Registry:

### ARTIFACT_REGISTRY_URL
- **Valor**: `us-central1-npm.pkg.dev/oute-app/npm/`
- **Usar para**: Publicar design-system package

## 3. SonarQube

Para integração com SonarQube Cloud:

### SONAR_TOKEN
- **Valor**: Token gerado em sonarcloud.io
- **Usar para**: SonarQube analysis nos workflows
- **Como obter**:
  1. Vá em https://sonarcloud.io
  2. Login com GitHub
  3. Create organization `oute`
  4. Generate token em Account → Security
  5. Copie o token

## 4. Slack Notifications (Opcional)

Para notificações de deploy em Slack:

### SLACK_WEBHOOK
- **Valor**: Webhook URL do canal Slack
- **Usar para**: Notificações de deploy
- **Como obter**:
  1. Vá em Slack Workspace → Apps
  2. Procure "Incoming Webhooks"
  3. Create New Webhook para seu canal
  4. Copie a URL

## 5. GitHub Token (Automático)

GitHub fornece automaticamente:

### GITHUB_TOKEN
- **Automático**: Fornecido por GitHub Actions
- **Permissões**: Configuradas no workflow
- **Usar para**: Upload SARIF, create releases

---

## Checklist de Setup

- [ ] Executado `setup-gcp.sh` (criou GCP_SA_KEY)
- [ ] `GCP_SA_KEY` adicionado ao GitHub Secrets
- [ ] `GCP_PROJECT_ID` adicionado
- [ ] `GCP_REGION` adicionado
- [ ] Criado SonarQube organization
- [ ] `SONAR_TOKEN` adicionado
- [ ] (Opcional) `SLACK_WEBHOOK` adicionado

## Branch Protection Rules

Configure em **Settings → Branches → Protect main**:

✅ Require a pull request before merging
✅ Require status checks to pass before merging
✅ Require code reviews before merging (1 reviewer min)
✅ Require branches to be up to date
✅ Include administrators

Status checks required:
- `lint`
- `typecheck`
- `test`
- `docker-build`
- `sonarqube`

Repita para branch `staging`.

## Testing Secrets

Para testar se os secrets estão corretos:

```bash
# No GitHub Actions, use:
- name: Test GCP credentials
  run: |
    echo "${{ secrets.GCP_SA_KEY }}" > /tmp/key.json
    gcloud auth activate-service-account --key-file=/tmp/key.json
    gcloud config set project ${{ secrets.GCP_PROJECT_ID }}
    gcloud projects list
```

## Troubleshooting

### "Secret not found"
- Verifique se secret foi adicionado em **Settings → Secrets**
- Verifique se o nome do secret é exato (case-sensitive)

### "Invalid GCP credentials"
- Verifique se `GCP_SA_KEY` é o JSON completo do arquivo
- Crie nova chave se a antiga expirou: `gcloud iam service-accounts keys create`

### "SonarQube quality gate failed"
- Verifique `SONAR_TOKEN` é válido
- Verifique se organization em sonarcloud.io corresponde ao workflow

---

**Todos os secrets configurados?** 🎉 Seus workflows estão prontos!

Faça um push para `develop` para testar o primeiro workflow.
