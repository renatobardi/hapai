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
cd hapai

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
docker logs hapai-dashboard -f
```

### Database
```bash
# Connect to PostgreSQL
psql -h localhost -U app-user -d hapai_db

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

### Unit tests
```bash
npm run test
```

Tests in `src/**/*.test.ts` and `src/**/*.spec.ts`

### E2E tests (TODO)
```bash
npm run test:e2e
```

## Type Safety

Check TypeScript across all packages:
```bash
npm run lint  # includes tsc --noEmit
```

Import from shared types:
```typescript
import type { User, Project } from '@hapai/shared';
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

## Resources

- [SvelteKit Docs](https://kit.svelte.dev)
- [Svelte 5 Docs](https://svelte.dev)
- [Tailwind CSS](https://tailwindcss.com)
- [SonarQube](https://www.sonarqube.org)
