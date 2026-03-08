# Arquitetura HAPAI

## Design Principles

1. **Monorepo Simples**: Um repo GitHub com estrutura clara
2. **Modular**: Cada domínio é independente mas compartilha tipos e componentes
3. **Escalável**: Adicione novos packages sem modificar código existente
4. **Type-Safe**: TypeScript strict mode em tudo
5. **Enterprise-Grade**: Qualidade e segurança desde o início

## Estrutura

```
hapai/
├── packages/
│   ├── design-system/    (Tokens + Componentes + Storybook)
│   ├── 00_dashboard/     (Frontend principal)
│   ├── 01_auth-profile/  (Auth API)
│   └── 02_projects/      (Projects API)
├── shared/               (Tipos comuns)
├── .github/              (CI/CD workflows)
└── [configs]
```

## Fluxo de Dados

```
00_dashboard (Port 3000)
    ├── Login → POST /auth/login (01_auth-profile)
    │   └── Recebe JWT
    ├── Dashboard → GET /projects (02_projects)
    │   └── Envia JWT no header
    └── Usa @hapai/design-system (componentes)

01_auth-profile (Port 3001)
    ├── POST /auth/login → Gera JWT
    ├── POST /auth/logout
    └── GET /profile (protegido)

02_projects (Port 3002)
    ├── Valida JWT via 01_auth-profile
    ├── GET /projects
    ├── POST /projects
    ├── GET /projects/:id
    ├── PUT /projects/:id
    └── DELETE /projects/:id
```

## Autenticação (JWT)

```
1. User faz login no 00_dashboard
   → POST http://localhost:3001/auth/login
   ← Recebe JWT

2. Dashboard armazena JWT (localStorage/cookie)

3. Para acessar 02_projects
   → GET http://localhost:3002/projects
   → Header: Authorization: Bearer <JWT>

4. 02_projects valida JWT
   ✅ Válido → Retorna dados
   ❌ Inválido → 401 Unauthorized
```

## Database

PostgreSQL centralizado compartilhado por todos os serviços.

**Schemas** (sugestão):
- `auth` - Tabelas de usuários, sessions
- `projects` - Tabelas de projetos
- `shared` - Dados comuns

## Design System (Tokens + Componentes)

```typescript
// Imports
import { Button, Card } from '@hapai/design-system';
import { colors, typography } from '@hapai/design-system/tokens';

// Uso
<Button variant="primary" size="md">Clique aqui</Button>
<Card title="Meu Card">Conteúdo</Card>
```

## Versionamento

Cada package tem seu próprio `package.json` com versão independente.

**Convenção**:
- Monorepo (raiz): v1.0.0
- design-system: v1.0.0, v1.1.0 (componentes novos)
- 00_dashboard: depende de design-system@^1.0.0
- 01_auth-profile, 02_projects: não dependem de design-system

## Deployment

### Ambiente Local (Docker)
```bash
npm run docker:up
```

Inicia:
- PostgreSQL (5432)
- 00_dashboard (3000)
- 01_auth-profile (3001)
- 02_projects (3002)
- design-system/storybook (6006)

### Cloud (GCP Cloud Run)
Cada package → Container separado:
- `hapai-dashboard` (Cloud Run Service)
- `hapai-auth-profile` (Cloud Run Service)
- `hapai-projects` (Cloud Run Service)

Todos compartilham Cloud SQL (PostgreSQL).

## CI/CD

6 workflows GitHub Actions:

1. **pull-request.yml** → Lint, tests, SonarQube
2. **merge-develop.yml** → Deploy preview
3. **merge-staging.yml** → E2E tests, deploy homolog
4. **merge-main.yml** → Deploy produção
5. **security-scan.yml** → SAST, DAST, secret scan
6. **dependency-check.yml** → Dependabot, licenses

## Code Quality

| Tool | Regra |
|------|-------|
| ESLint | Configuração compartilhada na raiz |
| Prettier | Auto-format em pre-commit |
| TypeScript | strict: true (não null check) |
| SonarQube | Quality gates (70% coverage, ratings A) |
| Trivy | Container scanning |
| git-secrets | Detecta secrets commitadas |

## Segurança

- JWT para autenticação stateless
- Secrets em GCP Secret Manager (prod)
- Variáveis de ambiente (dev)
- Trivy para container scanning
- Dependabot para vulnerabilities
- SAST (SonarQube) para code analysis

## Escalabilidade

### Adicionar novo package
1. Create `packages/NN_novo-servico/`
2. `npm create svelte@latest ...`
3. Extend `tsconfig.json` paths
4. Add Docker service em docker-compose.yml
5. Update CI/CD workflows
6. Document em SUBMODULES.md

### Adicionar novo componente ao design-system
1. Create `packages/design-system/src/components/NovoComponent.svelte`
2. Create `packages/design-system/stories/NovoComponent.stories.svelte`
3. Bump version em `packages/design-system/package.json`
4. Update `CHANGELOG.md`
5. `npm publish --workspace=design-system`

## Troubleshooting

### Porta já em uso
```bash
# Kill process na porta (ex: 3000)
lsof -i :3000 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

### Docker volume issue
```bash
docker volume prune
npm run docker:down
npm run docker:up
```

### Clean install
```bash
rm -rf node_modules packages/*/node_modules
npm install
```
