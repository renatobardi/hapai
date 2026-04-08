# Guia de Uso — hapai

## Instalação Rápida

```bash
# 1. Clone o repo
git clone https://github.com/renatobardi/hapai.git ~/hapai

# 2. Adicione ao PATH
ln -sf ~/hapai/bin/hapai /usr/local/bin/hapai

# 3. Instale globalmente (aplica a todos os projetos)
hapai install --global

# 4. Verifique
hapai validate
```

## Modos de Instalação

### Global (recomendado para começar)

```bash
hapai install --global
```

Instala em `~/.claude/settings.json` e `~/.hapai/`. Aplica a **todos** os projetos que você abrir com Claude Code.

### Por Projeto

```bash
cd meu-projeto
hapai install --project
```

Instala em `.claude/settings.json` do projeto. Útil para regras específicas por projeto (ex: proteger `CONSTITUTION.md` no the-loop).

### Os dois juntos

Você pode ter instalação global + projeto. O Claude Code carrega ambos. Hooks de projeto complementam os globais.

---

## Configuração (hapai.yaml)

Após instalar, um arquivo `hapai.yaml` é criado (em `~/.hapai/hapai.yaml` para global, ou `hapai.yaml` na raiz do projeto).

### Editando regras

Abra o arquivo e ajuste conforme seu projeto:

```yaml
version: "1.0"
risk_tier: medium

guardrails:
  # Quais branches são protegidas?
  branch_protection:
    enabled: true
    protected: [main, master, develop]  # adicione branches aqui
    fail_open: false                     # false = bloqueia, true = só avisa

  # Quais padrões são proibidos em commits?
  commit_hygiene:
    enabled: true
    blocked_patterns:
      - "Co-Authored-By:"
      - "Generated with Claude"
      - "noreply@anthropic.com"
      - "Claude Code"
      - "Anthropic"
    fail_open: false

  # Quais arquivos não podem ser editados pela IA?
  file_protection:
    enabled: true
    protected:
      - ".env"
      - ".env.*"
      - "*.lock"
      - "package-lock.json"
      - "pnpm-lock.yaml"
      - ".github/workflows/*"
      # Adicione arquivos específicos do seu projeto:
      # - "CONSTITUTION.md"
      # - "firebase.json"
    unprotected:
      - ".env.example"
      - ".env.sample"
    fail_open: false

  # Comandos perigosos bloqueados
  command_safety:
    enabled: true
    blocked:
      - "rm -rf"
      - "git push --force"
      - "git push -f"
      - "git reset --hard"
      - "DROP TABLE"
      - "DROP DATABASE"
      - "TRUNCATE"
      - "chmod 777"
    fail_open: false

  # Alerta quando commit é muito grande
  blast_radius:
    enabled: true
    max_files: 10       # alerta se >10 arquivos no commit
    max_packages: 2     # alerta se toca >2 pacotes (monorepo)
    fail_open: true     # true = avisa mas permite, false = bloqueia

  # Avisa quando a IA vai sobrescrever seu trabalho não-commitado
  uncommitted_changes:
    enabled: true
    fail_open: true

  # Branch taxonomy: enforce naming conventions (v1.3+)
  branch_taxonomy:
    enabled: true
    allowed_prefixes: [feat, fix, chore, docs, refactor, test, perf, style, ci, build]
    require_description: true   # require text after prefix/ (kebab-case)
    fail_open: false            # false = block, true = warn only

  # Branch rules: validate description + origin (v1.3+)
  branch_rules:
    enabled: true
    fail_open: false

  # PR review: mandatory background code review on all PRs (v1.3+)
  pr_review:
    enabled: false  # requires 'claude' CLI installed and authenticated
    model: "claude-haiku-4-5-20251001"
    fail_open: false
    review_timeout_seconds: 300
    max_diff_chars: 8000

  # Git workflow: trunk-based or GitFlow enforcement (v1.3+)
  git_workflow:
    enabled: false  # disabled by default — opt in per project
    model: trunk    # trunk | gitflow
    fail_open: true
```

### Configurando automação (opcional)

```yaml
automation:
  # Auto-checkpoint: cria snapshots git por arquivo editado
  auto_checkpoint:
    enabled: true          # ligue para nunca perder trabalho
    squash_on_stop: true   # consolida checkpoints ao fim da sessão
    commit_prefix: "checkpoint:"

  # Auto-format: roda formatter após cada escrita
  auto_format:
    enabled: true
    python: "ruff format {file}"
    javascript: "prettier --write {file}"

  # Auto-lint: roda linter após cada escrita
  auto_lint:
    enabled: true
    python: "ruff check {file}"
    javascript: "eslint {file}"
```

### O que é `fail_open`?

Cada guardrail tem um campo `fail_open`:
- **`false`** (padrão) = **Bloqueia**. A ação é impedida. Claude recebe mensagem de erro.
- **`true`** = **Avisa**. A ação é permitida, mas Claude recebe um aviso contextual.

Use `fail_open: true` para guardrails informativos (blast_radius, uncommitted_changes).
Use `fail_open: false` para guardrails invioláveis (branch_protection, commit_hygiene).

---

## Onde fica o quê?

```
~/.hapai/                    # Diretório global do hapai
├── hooks/                   # Scripts de hooks (instalados)
├── hapai.yaml               # Config global
├── audit.jsonl              # Log de tudo que os hooks fizeram
└── state/                   # Contadores e estado entre sessões

~/.claude/settings.json      # Hooks registrados aqui (global)
~/.claude/CLAUDE.md          # Regras injetadas aqui (<!-- hapai:start/end -->)

meu-projeto/
├── hapai.yaml               # Config por projeto (opcional, sobrescreve global)
├── .claude/settings.json    # Hooks registrados aqui (projeto)
└── CLAUDE.md                # Regras injetadas aqui (projeto)
```

---

## Usando o CLI

### Comandos do dia a dia

```bash
# Ver estado atual
hapai status

# Ver últimas 20 ações dos hooks
hapai audit

# Ver últimas 50 ações
hapai audit 50
```

### Emergência

```bash
# Desativa TODOS os hooks instantaneamente
hapai kill

# Reativa hooks
hapai revive
```

### Verificação

```bash
# Verifica se tudo está instalado corretamente
hapai validate
```

Output esperado:
```
hapai validate v1.0.0
─────────────────────────────────
✓ Hooks registered in /Users/you/.claude/settings.json
✓ Hook scripts: 11/11 executable in /Users/you/.hapai/hooks
✓ Global config: /Users/you/.hapai/hapai.yaml
✓ jq: jq-1.7.1
✓ Audit log: 42 entries
✓ State: 3 entries
─────────────────────────────────
All checks passed
```

### Exportar para outras ferramentas

```bash
# Gera .cursor/rules com as mesmas guardrails
hapai export --target cursor

# Gera .github/copilot-instructions.md
hapai export --target copilot
```

---

## Exemplos práticos

### Cenário 1: Claude tenta commitar na main

```
Claude: git commit -m "feat: add login"
hapai:  🛑 hapai: Commit blocked on protected branch 'main'.
        Create a feature branch first: git checkout -b feat/your-feature
```

### Cenário 2: Claude adiciona Co-Authored-By

```
Claude: git commit -m "feat: add button

        Co-Authored-By: Claude <noreply@anthropic.com>"
hapai:  🛑 hapai: Commit blocked — contains forbidden pattern 'Co-Authored-By:'.
        Remove AI attribution from the commit message.
```

### Cenário 3: Claude tenta rm -rf

```
Claude: rm -rf /
hapai:  🛑 hapai: Destructive command blocked — 'rm -rf' on dangerous path.
```

### Cenário 4: Claude edita .env

```
Claude: [Write] .env
hapai:  🛑 hapai: Write blocked — '.env' is a protected file.
        Environment files should not be modified by AI.
```

### Cenário 5: Commit grande (blast radius)

```
Claude: git commit -m "refactor: update everything"
hapai:  ⚠️ Blast radius: 15 files staged (threshold: 10).
        Also touches 3 packages (apps/web, apps/api, packages/ui).
        Consider splitting into smaller, focused commits.
```

---

## Configuração por projeto (exemplos)

### Para oute.me (monorepo SvelteKit + FastAPI)

```yaml
# oute.me/hapai.yaml
version: "1.0"
risk_tier: medium

guardrails:
  branch_protection:
    enabled: true
    protected: [main, develop]

  file_protection:
    enabled: true
    protected:
      - ".env"
      - ".env.*"
      - "*.lock"
      - ".github/workflows/*"
      - "turbo.json"
      - "pnpm-workspace.yaml"

automation:
  auto_format:
    enabled: true
    python: "ruff format {file}"
    javascript: "prettier --write {file}"

  auto_lint:
    enabled: true
    python: "ruff check {file}"
    javascript: "eslint {file}"
```

### Para the-loop (com CONSTITUTION.md)

```yaml
# the-loop/hapai.yaml
version: "1.0"
risk_tier: high

guardrails:
  branch_protection:
    enabled: true
    protected: [main]

  file_protection:
    enabled: true
    protected:
      - ".env"
      - "*.lock"
      - ".github/workflows/*"
      - "CONSTITUTION.md"
      - ".semgrep/*"

  blast_radius:
    enabled: true
    max_files: 8
    max_packages: 1
    fail_open: false   # bloqueia (mais rigoroso)
```

---

## Audit Log

Toda ação dos hooks é gravada em `~/.hapai/audit.jsonl`:

```json
{"ts":"2026-04-07T20:30:00Z","event":"PreToolUse","hook":"guard-branch","tool":"Bash","result":"deny","reason":"Commit blocked on protected branch 'main'","project":"/Users/bardi/Projetos/oute.me"}
{"ts":"2026-04-07T20:30:05Z","event":"PreToolUse","hook":"guard-branch","tool":"Bash","result":"allow","reason":"","project":"/Users/bardi/Projetos/oute.me"}
```

Use `hapai audit` para ver de forma legível, ou processe com `jq`:

```bash
# Quantos bloqueios por hook
jq -r 'select(.result=="deny") | .hook' ~/.hapai/audit.jsonl | sort | uniq -c | sort -rn

# Bloqueios das últimas 24h
jq -r 'select(.result=="deny")' ~/.hapai/audit.jsonl | tail -20
```

---

## Dupla camada: Hooks + CLAUDE.md

O `hapai install` injeta regras no CLAUDE.md do projeto usando markers:

```markdown
<!-- hapai:start -->
## Hapai Guardrails (enforced by hooks)
- NEVER commit directly to protected branches (main, master)
- NEVER add Co-Authored-By or mention AI/Claude in commits, PRs, or docs
...
<!-- hapai:end -->
```

Isso cria **duas camadas de proteção**:
1. **CLAUDE.md** (probabilístico) — Claude lê e tenta seguir
2. **Hooks** (determinístico) — Se Claude ignorar, o hook bloqueia

A injeção é idempotente: rodar `hapai install` novamente atualiza o bloco sem duplicar.

---

## Desinstalação

```bash
# Remove hooks globais
hapai uninstall --global

# Remove hooks do projeto atual
hapai uninstall
```

Isso remove hooks do `settings.json` e o bloco `<!-- hapai:start/end -->` do CLAUDE.md. Não apaga o audit log nem o estado.

---

## Export para Outras Ferramentas

hapai exporta as mesmas guardrails para 8 ferramentas AI. Os hooks (bloqueio real) são exclusivos do Claude Code, mas as regras em markdown funcionam como instrução para os outros:

```bash
# Exportar para ferramenta específica
hapai export --target cursor        # .cursor/rules/hapai.mdc
hapai export --target copilot       # .github/copilot-instructions.md
hapai export --target windsurf      # .windsurf/rules/hapai.md
hapai export --target devin         # AGENTS.md (append com markers)
hapai export --target trae          # .trae/rules/hapai.md
hapai export --target antigravity   # GEMINI.md + AGENTS.md
hapai export --target universal     # AGENTS.md (padrão cross-tool)
hapai export --target claude        # Valida instalação Claude Code

# Exportar para TODAS de uma vez
hapai export --all
```

Cada exporter gera o arquivo no formato correto da ferramenta (incluindo frontmatter quando necessário). O export é idempotente — rodar duas vezes não duplica conteúdo (usa markers `<!-- hapai:start/end -->`).

| Ferramenta | Arquivo gerado | Formato |
|-----------|---------------|---------|
| Cursor | `.cursor/rules/hapai.mdc` | MDC com `alwaysApply: true` |
| VS Code Copilot | `.github/copilot-instructions.md` | Markdown |
| Windsurf | `.windsurf/rules/hapai.md` | MD com `trigger: always_on` |
| Devin.ai | `AGENTS.md` | Markdown com markers hapai |
| Trae | `.trae/rules/hapai.md` | MD com `alwaysApply: true` |
| Antigravity | `GEMINI.md` + `AGENTS.md` | Markdown com markers hapai |
| Universal | `AGENTS.md` | Padrão cross-tool |

---

## Observabilidade (Fase 4)

Hooks que melhoram a experiência de desenvolvimento:

```yaml
# hapai.yaml
observability:
  require_tests:
    enabled: true          # avisa se nenhum teste rodou na sessão
    fail_open: true        # true = avisa, false = bloqueia

  backup_transcripts:
    enabled: true          # salva transcripts antes de compactação

  notifications:
    sound_enabled: true    # toca som quando Claude precisa de input

  auto_allow_readonly:
    enabled: true          # auto-aprova Read, Glob, Grep e comandos seguros
```

---

## Inteligência de Sessão (Fase 5)

Hooks que dão ao Claude consciência do contexto:

```yaml
# hapai.yaml
intelligence:
  production_warning:
    enabled: true          # avisa quando prompt menciona prod/deploy/release
    keywords: ["prod", "deploy", "rollback", "hotfix"]

  load_context:
    enabled: true          # carrega git status, TODOs e issues no início da sessão

  audit_trail:
    enabled: true          # loga TODA execução de tool em audit-trail.jsonl

  cost_tracker:
    enabled: true          # estima custo da sessão e avisa em thresholds
    max_tool_calls: 200
    max_cost_cents: 500
```

---

## Dúvidas Frequentes

**P: Os hooks afetam a velocidade do Claude Code?**
R: Mínimo. Cada hook roda em <100ms. PreToolUse tem timeout de 7s, PostToolUse de 5s. Se um hook travar, o timeout mata ele e o fluxo continua.

**P: E se eu precisar temporariamente editar um .env?**
R: Use `hapai kill` para desativar todos os hooks, faça a edição, e `hapai revive` para reativar. Ou edite `hapai.yaml` e adicione o arquivo à lista `unprotected`.

**P: Funciona com Cursor, Windsurf, Devin, Trae, Antigravity?**
R: Os hooks (bloqueio real) são exclusivos do Claude Code. Mas `hapai export --all` gera arquivos de regras para todas as ferramentas. Isso instrui cada ferramenta a seguir as mesmas regras — enforcement probabilístico, mas melhor que nada.

**P: Posso adicionar hooks customizados?**
R: Sim. Crie um script `.sh` em `~/.hapai/hooks/pre-tool-use/` (ou `post-tool-use/`, `stop/`), torne executável, e registre no `~/.claude/settings.json`. Use `hooks/_lib.sh` como biblioteca.

**P: O audit log cresce indefinidamente?**
R: Configure `retention_days` no `hapai.yaml`. Para limpar manualmente: `> ~/.hapai/audit.jsonl`

**P: O que é o AGENTS.md?**
R: É um padrão cross-tool (agents.md) para instrução de agentes AI. Devin, Antigravity, VS Code Copilot e Trae lêem esse arquivo automaticamente. `hapai export --target universal` gera/atualiza esse arquivo.

---

## Cloud Dashboard — Análise em Tempo Real (v1.4)

### Overview

O Dashboard hapai visualiza seus audit logs em um painel interativo em **GitHub Pages** com:
- Timeline de denials/warnings (últimos 30 dias)
- Top hooks que bloquearam mais
- Tabela de eventos recentes com detalhes (sortável)
- Distribuição por tool e por projeto
- Trends de deny rate

**Tecnologia:**
- **Frontend:** Svelte 5 + Vite (moderna, otimizada)
- **Autenticação:** GitHub OAuth via Firebase Auth
- **Backend:** Cloud Function (Python 3.12)
- **Dados:** BigQuery (analytics)
- **Deploy:** GitHub Pages (automático via Actions)

### Arquitetura

```
hapai audit logs (local)
    ↓
GitHub Actions (OIDC keyless auth)
    ↓
Cloud Storage bucket (gs://hapai-audit-{username})
    ↓
Cloud Function (triggered on upload)
    ↓
BigQuery dataset (hapai_dataset.events)
    ↓
Analytics Dashboard (GitHub Pages + Svelte)
    ↓
https://{owner}.github.io/{repo}/
```

### Setup Rápido

1. **Setup GCP infrastructure (first time only):**
   ```bash
   cd infra/gcp
   # Seguir infra/gcp/SETUP.md — todas as 6 fases
   # Cria: Workload Identity, Cloud Function, BigQuery, OIDC
   ```

2. **Configure GitHub Actions secrets:**
   Go to **GitHub Settings** → **Secrets and variables** → **Actions**
   
   Add these secrets:
   - `VITE_FIREBASE_API_KEY` — Firebase SDK key
   - `VITE_FIREBASE_APP_ID` — Firebase app ID
   - `VITE_BQ_PROXY_URL` — Cloud Function URL

3. **Deploy dashboard (automatic):**
   ```bash
   git push origin main  # Triggers workflow
   # .github/workflows/deploy-dashboard.yml builds and deploys
   ```

4. **Dashboard is live at:**
   - `https://{owner}.github.io/{repo}/`
   - Example: `https://renatobardi.github.io/hapai/`

5. **Sign in with GitHub:**
   Click "Sign in with GitHub" button
   Dashboard loads and syncs audit logs from BigQuery

### Cloud Logging — Sync Audit Logs (Optional)

If you want to monitor guardrails across your team with real-time analytics:

**Enable in hapai.yaml:**
```yaml
gcp:
  enabled: true
  project_id: your-gcp-project
  bucket: hapai-audit-{username}
  region: us-east1
  retention_days: 90
```

**Trigger sync:**
```bash
# Manual
hapai sync

# Automatic: GitHub Actions (OIDC)
# .github/workflows/hapai-sync.yml runs daily @ 2 AM UTC
```

**Monitor in BigQuery:**
```bash
bq query 'SELECT * FROM hapai_dataset.events ORDER BY ts DESC LIMIT 100'
```

### Dashboard Features

- **Timeline**: Daily denial/warning counts
- **Top Blocking Hooks**: Which guardrails are most active
- **Recent Events**: Live feed of all denials/warnings
- **Tool Distribution**: Which tools trigger guards
- **Project Breakdown**: Per-project statistics
- **Deny Rate Trends**: Historical analysis

### Troubleshooting

**Dashboard shows "Sign in with GitHub" but no data:**
- Ensure BigQuery has data: `bq query 'SELECT COUNT(*) FROM hapai_dataset.events'`
- Check Cloud Function logs: `gcloud functions logs read bq-query --gen2 --limit 20`
- Verify Firebase config in GitHub Actions secrets

**Cloud Function 404 errors:**
- Ensure Cloud Function URL is correct in `VITE_BQ_PROXY_URL`
- Check function is deployed: `gcloud functions list --gen2`
- View logs: `gcloud functions logs read bq-query --gen2`

**No data in BigQuery:**
- Trigger Cloud Function manually: `gcloud scheduler jobs run hapai-sync-trigger --location=us-east1`
- Check Cloud Storage for uploaded files: `gsutil ls gs://hapai-audit-{username}/ --recursive`
- View Cloud Function logs for errors

### Comandos do Dashboard

```bash
# Sincronizar audit logs para Cloud Storage
hapai sync

# Preview da sincronização (sem fazer upload)
hapai sync --dry-run

# Verificar logs de sincronização
tail ~/.hapai/sync.log

# Verificar uploads no Cloud Storage
gsutil ls -r "gs://hapai-audit-username/"
```

### Configuração

```yaml
# hapai.yaml
gcp:
  enabled: true              # ativar/desativar sync
  project_id: hapai-oute     # seu GCP project
  bucket: hapai-audit-you    # Cloud Storage bucket
  region: us-east1           # GCP region
  retention_days: 90         # manter dados por 90 dias no BigQuery
```

### Autenticação no Dashboard

O dashboard usa **Google OAuth2** para:
1. Você faz login com sua conta Google
2. Dashboard acessa **sua** autorização do BigQuery
3. Não guardamos token — ele fica no localStorage do seu browser

**Nota:** Você precisa ter acesso ao dataset `hapai_dataset` no GCP.

### Consultas BigQuery (exemplos)

```sql
-- Top 10 hooks que bloquearam mais
SELECT hook, COUNT(*) as blocks
FROM `project.hapai_dataset.events`
WHERE event = 'deny'
  AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY hook
ORDER BY blocks DESC
LIMIT 10;

-- Timeline de denials por dia
SELECT DATE(ts) as day, COUNT(*) as denials
FROM `project.hapai_dataset.events`
WHERE event = 'deny'
  AND ts >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY day
ORDER BY day DESC;

-- Correlações: quais hooks negaram juntos
SELECT h1, h2, COUNT(*) as frequency
FROM (
  SELECT 
    LAG(hook) OVER (PARTITION BY DATE(ts) ORDER BY ts) as h1,
    hook as h2
  FROM `project.hapai_dataset.events`
  WHERE event = 'deny'
)
WHERE h1 IS NOT NULL
GROUP BY h1, h2
ORDER BY frequency DESC
LIMIT 20;
```

### Troubleshooting Dashboard

**"Sync failed: GOOGLE_APPLICATION_CREDENTIALS not set"**
```bash
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcp-sa-key.json
hapai sync
```

**"Permission denied" no BigQuery**
- Verifique que seu service account tem `roles/bigquery.dataEditor` no dataset
- Ou use sua própria conta Google (OAuth2 no dashboard usa sua conta, não a service account)

**Cloud Function não triggerou (arquivo não carregou no BigQuery)**
```bash
# Verificar logs da função
gcloud functions logs read hapai-load-audit --limit 50

# Triggeração manual
gsutil cp test.jsonl gs://hapai-audit-you/2026-04/test.jsonl
```

**Dashboard não mostra dados**
1. Verifique se sync rodar: `hapai sync`
2. Verifique se Cloud Function processou: `gcloud functions logs read hapai-load-audit`
3. Query BigQuery manualmente: `bq query --use_legacy_sql=false 'SELECT * FROM hapai_dataset.events LIMIT 5'`
4. Limpe localStorage do navegador: Ctrl+Shift+Delete → Cookies and other site data

### Documentação Completa

Para setup detalhado, passo a passo, com todos os comandos gcloud:
→ **[infra/gcp/SETUP.md](infra/gcp/SETUP.md)**
