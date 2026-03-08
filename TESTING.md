# Testing HAPAI Locally

Guia para testar a aplicação HAPAI em ambiente local.

## Pré-requisitos

- Node.js 20+ instalado
- npm instalado
- Docker (opcional, para rodar PostgreSQL)

## Setup Inicial

### 1. Instalar Dependências

```bash
# Na raiz do monorepo
npm install
```

Isso instala dependências para todos os packages usando npm workspaces.

### 2. Configurar Variáveis de Ambiente

Cada package tem um arquivo `.env.example`. Copie para `.env`:

```bash
# 00_dashboard
cp packages/00_dashboard/.env.example packages/00_dashboard/.env

# 01_auth-profile
cp packages/01_auth-profile/.env.example packages/01_auth-profile/.env

# 02_projects
cp packages/02_projects/.env.example packages/02_projects/.env
```

### 3. (Opcional) Rodar PostgreSQL com Docker

```bash
docker-compose up -d postgres
```

Aguarde ~5 segundos para o banco estar pronto.

---

## Executar Localmente

### Opção A: Rodar Tudo com Docker Compose

```bash
docker-compose up
```

Serviços disponíveis:
- **Dashboard**: http://localhost:3000
- **Auth Service**: http://localhost:3001
- **Projects Service**: http://localhost:3002
- **Design System (Storybook)**: http://localhost:6006

### Opção B: Rodar Manualmente (sem Docker)

#### Terminal 1: PostgreSQL
```bash
docker run --name hapai-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=hapai_db \
  -p 5432:5432 \
  postgres:15-alpine
```

#### Terminal 2: Design System (Storybook)
```bash
cd packages/design-system
npm run dev:storybook
```

#### Terminal 3: Auth Service
```bash
cd packages/01_auth-profile
npm run dev
```

#### Terminal 4: Projects Service
```bash
cd packages/02_projects
npm run dev
```

#### Terminal 5: Dashboard
```bash
cd packages/00_dashboard
npm run dev
```

Após alguns segundos:
- Dashboard: http://localhost:3000

---

## Testar a Aplicação

### 1. Login (00_dashboard)

Visite http://localhost:3000

**Credenciais de demonstração**:
- Email: `demo@example.com`
- Senha: `password123`

> **Nota**: Você verá "Hello World! 🚀" se o setup estiver correto. O formulário de login funcionará quando o serviço 01_auth-profile estiver rodando.

### 2. Verificar Componentes do Design System

Visite http://localhost:6006 para ver o Storybook com:
- Button (primary, secondary, danger)
- Card
- Input
- Cores disponíveis
- Tipografia

### 3. Testar APIs Manualmente (cURL)

#### Login
```bash
curl -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@example.com",
    "password": "password123"
  }'
```

Resposta (salve o token):
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "uuid-123",
    "email": "demo@example.com",
    "name": "Demo User"
  }
}
```

#### Buscar Projetos
```bash
# Substitua TOKEN pelo token do login acima
curl http://localhost:3002/projects \
  -H "Authorization: Bearer TOKEN"
```

---

## Troubleshooting

### Erro: "Cannot find module '@hapai/design-system'"

**Solução**: Rode `npm install` na raiz do monorepo para instalar workspaces:
```bash
npm install
```

### Erro: "Port 3000 already in use"

**Solução**: Mude a porta em vite.config.ts ou mate o processo usando a porta:
```bash
# macOS/Linux
lsof -i :3000
kill -9 <PID>

# Windows
netstat -ano | findstr :3000
taskkill /PID <PID> /F
```

### Erro: "Connection refused" ao fazer requests para 01_auth-profile

**Solução**: Certifique-se de que o serviço está rodando:
```bash
cd packages/01_auth-profile
npm run dev
```

### Erro: "Database connection error"

**Solução**: Verifique se PostgreSQL está rodando:
```bash
docker ps | grep postgres
```

Se não estiver, inicie:
```bash
docker-compose up -d postgres
```

---

## Scripts Disponíveis

### Raiz (npm)

```bash
npm run dev                 # Rodar todos os packages em dev
npm run build              # Build de todos
npm run lint               # Lint de todos
npm run format             # Prettier em todos
npm run test               # Testes de todos

npm run docker:build       # Build das imagens Docker
npm run docker:up          # Subir docker-compose
npm run docker:down        # Descer docker-compose
npm run docker:logs        # Ver logs do docker-compose
```

### Por Package

```bash
cd packages/00_dashboard
npm run dev                # Dev server (port 3000)
npm run build              # Build para produção
npm run preview            # Preview da build
npm run check              # TypeScript check
npm run lint               # ESLint
```

---

## Next Steps

Após testar o "Hello World", as próximas implementações são:

1. **Dashboard**: Página de projetos (lista, criar, editar)
2. **Auth Service**: Implementar rotas POST /auth/login, /auth/logout, GET /profile
3. **Projects Service**: Implementar CRUD de projetos
4. **Database**: Scripts de migração e seeding
5. **CI/CD**: Configure GitHub Actions e GCP

---

## Dúvidas?

Ver documentação:
- **DEVELOPMENT.md**: Setup detalhado
- **ARCHITECTURE.md**: Decisões arquiteturais
- **INTEGRATIONS.md**: Fluxos de integração entre serviços
