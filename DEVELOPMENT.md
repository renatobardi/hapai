# Development Guide

## Setup Local

### 1. Prerequisites
- Node.js 20+
- npm 10+
- Docker & Docker Compose
- Git

### 2. Installation

```bash
# Clone repo
git clone https://github.com/seu-usuario/oute.git
cd oute

# Install all dependencies (workspaces)
npm install

# Copy env template
cp .env.example .env.local
```

### 3. Start Development

**Option A: With Docker (Recommended)**
```bash
npm run docker:up
```

Services available:
- Dashboard: http://localhost:3000
- Auth API: http://localhost:3001
- Projects API: http://localhost:3002
- PostgreSQL: localhost:5432
- Design System: http://localhost:6006

**Option B: Local without Docker**
```bash
npm run dev

# In separate terminals:
cd packages/00_dashboard && npm run dev
cd packages/01_auth-profile && npm run dev
cd packages/02_projects && npm run dev
```

## Scripts

### Root level
```bash
npm run dev              # All packages dev mode
npm run build            # All packages build
npm run test             # All packages test
npm run lint             # ESLint + TypeScript check
npm run format           # Prettier format

npm run docker:up        # Start Docker services
npm run docker:down      # Stop Docker services
npm run docker:logs      # View logs
npm run docker:build     # Rebuild images

npm run storybook:design-system  # Start Storybook for design-system
```

### Per package
```bash
cd packages/00_dashboard
npm run dev              # Dev server
npm run build            # Build for prod
npm run preview          # Preview built app

npm run lint             # Lint this package
npm run format           # Format this package
npm run test             # Test this package
```

## Pre-commit Hooks

Using Husky for git hooks:

```bash
npm install husky --save-dev
npx husky install

# Hooks installed:
# - Pre-commit: ESLint, Prettier, git-secrets
# - Pre-push: TypeScript check
```

## Debugging

### View logs
```bash
npm run docker:logs

# Or specific service
docker logs oute-dashboard -f
```

### Database
```bash
# Connect to PostgreSQL
psql -h localhost -U app-user -d oute_db

# List tables
\dt

# View data
SELECT * FROM users;
```

### Browser DevTools
SvelteKit includes Svelte DevTools in development.

## Creating Features

### 1. Create branch
```bash
git checkout -b feature/my-feature develop
```

### 2. Make changes
Edit files, test locally, etc.

### 3. Commit
```bash
git commit -m "feat(dashboard): add new button component"
```

**Commit types**: feat, fix, docs, style, refactor, test, chore, ci

### 4. Push & PR
```bash
git push origin feature/my-feature
```

Open PR on GitHub to `develop` branch.

### 5. Merge
After reviews and checks pass:
```bash
git checkout develop
git pull
git merge --squash feature/my-feature
git commit -m "feat: merge new feature"
git push
```

## Design System Development

### Adding a new component

```bash
# Create component file
touch packages/design-system/src/components/MyComponent.svelte
```

**MyComponent.svelte**
```svelte
<script lang="ts">
  export let variant: 'primary' | 'secondary' = 'primary';
  export let disabled = false;
</script>

<button class="my-component" {variant} {disabled}>
  <slot />
</button>

<style>
  .my-component { ... }
</style>
```

### Create Storybook story
```bash
touch packages/design-system/stories/MyComponent.stories.svelte
```

**MyComponent.stories.svelte**
```svelte
<script>
  import MyComponent from '../src/components/MyComponent.svelte';
</script>

<Meta title="Components/MyComponent" />

<Story name="Primary">
  <MyComponent variant="primary">Click me</MyComponent>
</Story>

<Story name="Disabled">
  <MyComponent disabled>Disabled</MyComponent>
</Story>
```

### Publish new version
```bash
cd packages/design-system

# Update version in package.json
# v1.0.0 → v1.0.1 (patch)
# v1.0.0 → v1.1.0 (minor - new components)
# v1.0.0 → v2.0.0 (major - breaking changes)

# Update CHANGELOG.md

npm publish
```

## Testing

### Running Tests

**Run all tests:**
```bash
npm run test
```

**Run tests in watch mode (local development):**
```bash
npm run test -- --watch
```

**Run tests with coverage report:**
```bash
npm run test -- --run --coverage
```

### Test File Conventions

Tests are located in `src/**/*.test.ts` files:
- `src/components/Button.test.ts` - Component tests
- `src/utils/helpers.test.ts` - Utility function tests
- `src/services/auth.test.ts` - Service/API tests

**Note:** E2E tests (*.spec.ts) are separate and run with Playwright.

### Coverage Requirements

All PRs must maintain **minimum 80% code coverage** across all packages:

- **Lines:** 80%
- **Branches:** 75%
- **Functions:** 80%
- **Statements:** 80%

Coverage is enforced by:
1. Local check before committing: `npm run test -- --run --coverage`
2. GitHub Actions PR checks
3. SonarQube quality gate analysis

**What's excluded from coverage:**
- `node_modules/`
- `dist/`, `build/` directories
- Test files themselves (*.test.ts, *.spec.ts)
- Index files (index.ts)

### E2E Tests with Playwright

E2E tests verify critical user workflows across the entire application.

**Run E2E tests:**
```bash
npm run test:e2e
```

**E2E test file format:** `src/**/*.spec.ts`

Example E2E test structure:
```typescript
// src/auth/login.spec.ts
import { test, expect } from '@playwright/test';

test('User can login and access dashboard', async ({ page }) => {
  await page.goto('http://localhost:3000/auth/login');
  await page.fill('input[name="email"]', 'user@example.com');
  await page.fill('input[name="password"]', 'password123');
  await page.click('button:has-text("Login")');

  await expect(page).toHaveURL('http://localhost:3000/dashboard');
  await expect(page.locator('h1')).toContainText('Dashboard');
});
```

Critical workflows to test:
- Authentication (login, logout, password reset)
- Dashboard data loading and rendering
- Project CRUD operations
- Error handling and validation

### Before Opening a Pull Request

**ALWAYS run these locally:**
```bash
# 1. Run tests with coverage
npm run test -- --run --coverage

# 2. Check your coverage percentage
# View in coverage/index.html or terminal output

# 3. If coverage < 80%, add tests for uncovered lines

# 4. Run linter
npm run lint

# 5. Run formatter
npm run format

# 6. Build project
npm run build

# 7. Only after all pass, commit and push
git commit -m "feat: your feature description"
git push origin feature/your-feature
```

### Quality Standards in CI/CD

When you open a PR, GitHub Actions automatically runs:

✅ **Code Quality Checks:**
- ESLint with strict rules
- Prettier code formatting
- TypeScript strict mode checks

✅ **Test Coverage Verification:**
- All tests must pass
- Coverage must be ≥80% on new code
- SonarQube analyzes coverage

✅ **Security Scans:**
- npm audit for vulnerabilities (blocks on HIGH/CRITICAL)
- Secret scanning for credentials
- OWASP Dependency Check
- SonarQube security analysis

✅ **SonarQube Quality Gate (MANDATORY):**
- Overall grade: A- or better
- Security rating: A
- Reliability rating: A
- Maintainability rating: A
- Code duplication: <3%
- No critical code smells
- No vulnerabilities

**If any check fails, your PR cannot be merged.** See [QUALITY_STANDARDS.md](./QUALITY_STANDARDS.md) for detailed quality requirements and troubleshooting.

### Debugging Tests

**Debug a specific test file:**
```bash
npm run test -- src/utils/helpers.test.ts --watch
```

**Debug with verbose output:**
```bash
npm run test -- --reporter=verbose
```

**View coverage details:**
```bash
# After running test with coverage
open coverage/index.html
```

**Common test issues:**
- Test timeout: Increase timeout in vitest config or test file
- Import errors: Check @oute/shared types are exported correctly
- Assertion failures: Review test output for exact vs. expected values
- E2E test flakiness: Add waitFor conditions, increase timeouts

## Quality Standards Reference

This project enforces strict code quality and security standards. All PRs must meet requirements detailed in [QUALITY_STANDARDS.md](./QUALITY_STANDARDS.md).

### Quick Checklist Before PR

- ✅ Code coverage ≥80% locally (`npm run test -- --run --coverage`)
- ✅ All linting errors fixed (`npm run lint`)
- ✅ Code formatted (`npm run format`)
- ✅ Build succeeds (`npm run build`)
- ✅ No console.log statements (ESLint blocks them)
- ✅ No `any` types in TypeScript (ESLint blocks them)
- ✅ All imports used (no unused variables)
- ✅ No security vulnerabilities (`npm audit`)

If any of these fail locally, fix them before pushing. GitHub Actions will enforce all of these plus additional security and quality scans.

For detailed information on:
- Quality gates and thresholds → [QUALITY_STANDARDS.md](./QUALITY_STANDARDS.md)
- SonarQube analysis → [QUALITY_STANDARDS.md](./QUALITY_STANDARDS.md#sonarqube-analysis)
- Security scanning → [QUALITY_STANDARDS.md](./QUALITY_STANDARDS.md#security-scanning)
- Troubleshooting failed checks → [QUALITY_STANDARDS.md](./QUALITY_STANDARDS.md#troubleshooting-common-issues)

## Type Safety

Check TypeScript across all packages:
```bash
npm run lint  # includes tsc --noEmit
```

Import from shared types:
```typescript
import type { User, Project } from '@oute/shared';
```

## Troubleshooting

### Port already in use
```bash
lsof -i :3000 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

### Node modules corrupted
```bash
rm -rf node_modules packages/*/node_modules
npm install
```

### Docker issues
```bash
docker-compose down -v
npm run docker:up
```

### Git pre-commit hook failing
If hooks are failing, check what's failing:
```bash
npm run lint      # ESLint
npm run format    # Prettier
npm run test      # Tests
```

## Performance Tips

1. **Use npm workspaces correctly**
   - Dependencies installed once at root
   - Avoid duplicate installs

2. **Docker caching**
   - Use multi-stage Dockerfile
   - Layer dependencies early

3. **SvelteKit optimization**
   - Use `+server.ts` for API routes
   - Implement proper data loading
   - Enable Adapter auto mode

## CI/CD Pipeline

### Automatic Deployment (GitHub Actions)

Cada push para `main` dispara um pipeline automático:

```
git push origin main
    ↓
✓ Build & Test (~2 min)
    ├─ ESLint
    ├─ TypeScript check
    ├─ Build dashboard
    └─ Upload artifacts
    ↓
✓ Deploy Production (~5 min)
    ├─ Docker build & push
    ├─ Deploy to Cloud Run
    ├─ Health checks
    ├─ Create GitHub release
    └─ Post deployment summary
    ↓
✅ Live em produção!
```

### Before Pushing to main

Always ensure code meets quality standards before pushing:

```bash
# 1. Run tests with coverage (MUST be ≥80%)
npm run test -- --run --coverage

# 2. Check test coverage output
# If < 80%, add more tests before proceeding

# 3. Run linter (ALL errors must be fixed)
npm run lint

# 4. Run formatter
npm run format

# 5. Build all packages
npm run build

# 6. If all checks pass, create PR instead of pushing directly
git commit -m "feat: nova funcionalidade"
git push origin feature/your-feature

# 7. Open PR to develop/staging branch
# Wait for GitHub Actions to run all checks
# Address any failing checks
# Request review from team
```

**Never push directly to `main`** - always use feature branches and open PRs for code review.

### Monitorar Pipeline

```bash
# Ver últimos workflows
gh run list --repo renatobardi/oute-main --limit 3

# Ver logs detalhados
gh run view <run-id> --log

# Aguardar conclusão
gh run watch <run-id>

# Acessar em produção após sucesso
https://oute-dashboard-kx25r3idia-uc.a.run.app
```

### Rollback em Produção

Se algo der errado em produção:

```bash
# Listar revisions anteriores
gcloud run revisions list --service=oute-dashboard --region=us-central1

# Reverter para revision anterior
gcloud run services update-traffic oute-dashboard \
  --region=us-central1 \
  --to-revisions=<REVISION-ID>=100
```

Para mais detalhes, ver [.github/CI_CD_PIPELINE.md](./.github/CI_CD_PIPELINE.md)

## Resources

- [SvelteKit Docs](https://kit.svelte.dev)
- [Svelte 5 Docs](https://svelte.dev)
- [Tailwind CSS](https://tailwindcss.com)
- [SonarQube](https://www.sonarqube.org)
- [CI/CD Pipeline Docs](./.github/CI_CD_PIPELINE.md)
- [Deployment Guide](./DEPLOYMENT.md)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Cloud Run Docs](https://cloud.google.com/run/docs)
