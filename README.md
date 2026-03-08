# OUTE - Modular Monorepo

OUTE é uma aplicação modular construída com **Svelte 5 + SvelteKit**, organizada como um monorepo com múltiplos domínios independentes. A arquitetura suporta escalabilidade, deployment em **GCP Cloud Run** e implementa padrões enterprise de qualidade e segurança.

## 🏗️ Arquitetura

```
packages/
├── design-system/     ← Tailwind 4 + Componentes reutilizáveis
├── 00_dashboard/      ← Interface principal
├── 01_auth-profile/   ← ✅ REFATORADO: Hexagonal Architecture + DDD + TDD
└── 02_projects/       ← Gerenciamento de projetos

shared/               ← Tipos e utilitários compartilhados
```

### ✅ 01_auth-profile - Refatoração Completa

O serviço `01_auth-profile` foi completamente refatorado seguindo:

- **Hexagonal Architecture**: Domain isolado, Ports & Adapters
- **Domain-Driven Design**: Entities, Value Objects, Aggregates
- **Clean Code**: SOLID principles, clear naming, small functions
- **Test-Driven Development**: 178 testes (56 unit + 28 integration + 34 app + 39 presentation + 21 E2E)
- **Professional Standards**: Definition of Done, Definition of Ready
- **80%+ Code Coverage**: Tested in all layers

**Status**: ✅ Production-ready com documentação completa

**Próximas ações**: Aplicar o mesmo padrão a 00_dashboard e 02_projects.
Ver: [APPLYING_PATTERN_TO_OTHER_SERVICES.md](./APPLYING_PATTERN_TO_OTHER_SERVICES.md)

## 🚀 Quick Start

### Pré-requisitos
- Node.js 20+ (LTS)
- npm 10+
- Docker & Docker Compose (para desenvolvimento local)

### Setup Local

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/oute.git
cd oute

# Instale dependências (todos os packages)
npm install

# Inicie os serviços em Docker
npm run docker:up

# Ou, para desenvolvimento local sem Docker
npm run dev
```

Serviços rodando:
- **Dashboard**: http://localhost:3000
- **Auth-Profile**: http://localhost:3001
- **Projects**: http://localhost:3002
- **Design System (Storybook)**: http://localhost:6006
- **PostgreSQL**: localhost:5432

## 📦 Packages

### 1. **design-system** (packages/design-system)
Sistema de design modular com Tailwind 4, componentes reutilizáveis e Storybook.

```bash
npm run dev:storybook --workspace=design-system
```

### 2. **00_dashboard** (packages/00_dashboard)
Interface web principal. Acessa auth-profile e projects.

### 3. **01_auth-profile** (packages/01_auth-profile)
Serviço de autenticação que emite JWTs. Todos os outros serviços validam tokens aqui.

### 4. **02_projects** (packages/02_projects)
API de gerenciamento de projetos com CRUD completo.

## 📚 Documentação

### 🎯 Refactoring & Arquitetura
- **[EXECUTIVE_SUMMARY.md](./EXECUTIVE_SUMMARY.md)** - 📊 **LEIA PRIMEIRO**: Resumo executivo da refatoração completa
- **[REFACTORING_COMPLETION.md](./REFACTORING_COMPLETION.md)** - 🏆 Relatório completo: Hexagonal Architecture + DDD + Clean Code + TDD
- **[PHASE_1_SUMMARY.md](./packages/01_auth-profile/PHASE_1_SUMMARY.md)** - 📚 Domain Layer (Entities, Value Objects, Errors)
- **[PHASE_2_SUMMARY.md](./packages/01_auth-profile/PHASE_2_SUMMARY.md)** - 🔧 Infrastructure Layer (Adapters, Repositories)
- **[PHASE_3_SUMMARY.md](./packages/01_auth-profile/PHASE_3_SUMMARY.md)** - ⚙️ Application Layer (Use Cases, DTOs)
- **[PHASE_4_SUMMARY.md](./packages/01_auth-profile/PHASE_4_SUMMARY.md)** - 🌐 Presentation Layer (Handlers, Routes)
- **[PHASE_5_SUMMARY.md](./packages/01_auth-profile/PHASE_5_SUMMARY.md)** - 🧪 E2E Tests (Playwright, Test Suite)

### 🚀 Implementação & Padrões
- **[APPLYING_PATTERN_TO_OTHER_SERVICES.md](./APPLYING_PATTERN_TO_OTHER_SERVICES.md)** - 📋 Template para aplicar padrão a 00_dashboard e 02_projects
- **[NEXT_STEPS_CHECKLIST.md](./NEXT_STEPS_CHECKLIST.md)** - ✅ Checklist de próximas ações e verificação

### 📖 Documentação Técnica
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - 🏗️ Decisões arquiteturais e fluxos de dados
- **[DEVELOPMENT.md](./DEVELOPMENT.md)** - 💻 Setup local, debugging, scripts
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - ☁️ Deploy em GCP Cloud Run
- **[SUBMODULES.md](./SUBMODULES.md)** - 📦 Detalhes de cada domínio

## 🔄 Workflow

### Branches
- **main** → Produção
- **staging** → Pré-produção (homolog)
- **develop** → Desenvolvimento
- **feature/*** → Novas features

### Criar uma feature

```bash
git checkout -b feature/meu-recurso develop
# ... faz mudanças ...
git push origin feature/meu-recurso
# Abre PR para develop
```

## 🛠️ Scripts Principais

### Desenvolvimento
```bash
npm run dev           # Todos os packages em dev
npm run build         # Build todos os packages
npm run lint          # ESLint + TS check
npm run format        # Prettier format
```

### Testing (178 tests, 80%+ coverage)
```bash
npm run test          # Rodar todos os testes
npm run test:e2e      # E2E tests (Playwright)
npm run test -- --watch     # Watch mode
npm run test -- --coverage  # Coverage report
```

### Docker
```bash
npm run docker:up     # Start Docker services
npm run docker:down   # Stop Docker services
npm run docker:logs   # Ver logs
```

## 🔐 Segurança & Qualidade

- ✅ **TypeScript strict mode**
- ✅ **ESLint + Prettier**
- ✅ **SonarQube** (Community Edition)
- ✅ **Trivy** (container scanning)
- ✅ **Dependabot** (dependency updates)
- ✅ **Pre-commit hooks** (git-secrets, lint, format)

## ☁️ Deployment

Deploy automático em GCP Cloud Run via GitHub Actions:

1. **PR** → Lint, tests, SonarQube checks
2. **develop** → Deploy em preview
3. **staging** → Deploy em homolog
4. **main** → Deploy em produção

Ver [DEPLOYMENT.md](./DEPLOYMENT.md) para detalhes.

## 📦 Stack Técnico

- **Frontend**: Svelte 5, SvelteKit, Tailwind 4
- **Backend**: SvelteKit API routes, Node.js
- **Database**: PostgreSQL (centralizado)
- **Auth**: JWT (JSON Web Token)
- **Cloud**: GCP Cloud Run, Cloud SQL, Artifact Registry, Secret Manager
- **CI/CD**: GitHub Actions
- **Code Quality**: SonarQube, ESLint, TypeScript
- **Containers**: Docker, docker-compose

## 📋 Roadmap

- [ ] v1.0.0 - Setup initial
- [ ] v1.1.0 - Dashboard features
- [ ] v1.2.0 - Projects management
- [ ] v2.0.0 - Real-time updates (WebSockets)

## 🤝 Contributing

1. Create feature branch
2. Commit with message pattern: `type(scope): description`
3. Open PR with description
4. Wait for reviews + status checks

Ver [contributing.md](./contributing.md) para mais detalhes.

## 📝 License

MIT

---

**Made with ❤️ using Svelte 5 + SvelteKit**