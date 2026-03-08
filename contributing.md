# Contributing Guide

Thank you for contributing to OUTE! This guide explains how to work on this project.

## Code of Conduct

- Be respectful and inclusive
- Ask questions if unsure
- Help others when you can
- Report issues professionally

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a feature branch
4. Make your changes
5. Push to your fork
6. Submit a pull request

## Branch Naming

Follow this pattern:

```
feature/short-description     ← New features
fix/short-description         ← Bug fixes
docs/short-description        ← Documentation
refactor/short-description    ← Code refactoring
test/short-description        ← Tests
chore/short-description       ← Maintenance
```

Examples:
- `feature/add-user-auth`
- `fix/dashboard-loading-bug`
- `docs/update-readme`

## Commit Messages

Format:
```
type(scope): subject

body (optional)

footer (optional)
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`

**Scope**: Package or feature area (optional)

**Examples**:
```
feat(auth): add JWT token refresh mechanism

- Implement refresh endpoint in 01_auth-profile
- Update 00_dashboard to use refresh tokens
- Add error handling for expired tokens

Closes #42
```

```
fix(dashboard): resolve loading state not clearing
```

```
docs: update ARCHITECTURE.md with new flow diagram
```

## Pull Request Process

1. **Before you start**
   - Check existing PRs/issues to avoid duplicate work
   - Create an issue if feature is major

2. **Develop your feature**
   ```bash
   git checkout -b feature/my-feature develop
   # Make changes, test locally
   npm run lint
   npm run test
   ```

3. **Commit your changes**
   ```bash
   git commit -m "feat(scope): description"
   git push origin feature/my-feature
   ```

4. **Open PR on GitHub**
   - Title: Short, descriptive
   - Description: What changed and why
   - Reference related issues: `Closes #123`

5. **Wait for reviews**
   - CI/CD must pass (lint, tests, SonarQube)
   - Minimum 1 review approval required
   - Address feedback in new commits

6. **Merge**
   - Use squash + merge to keep history clean
   - Delete feature branch after merge

## Code Style

### TypeScript
- Use `strict: true` mode
- Avoid `any` types
- Export types from `shared/`

```typescript
import type { User } from '@oute/shared';

export function getUser(id: string): User | null {
  // ...
}
```

### Svelte
- Use `<script lang="ts">` in all components
- Props with explicit types
- Reactive declarations with `$:`

```svelte
<script lang="ts">
  export let title: string;
  export let disabled: boolean = false;

  let isOpen: boolean = false;

  $: isDisabled = disabled || isOpen;
</script>

<button {disabled}>{title}</button>
```

### Formatting
- ESLint + Prettier automatically enforces style
- Run `npm run format` before committing
- Pre-commit hooks will catch violations

## Testing

- Write tests for new features
- Unit tests: `src/**/*.test.ts`
- E2E tests: `e2e/**/*.spec.ts`
- Aim for 70%+ coverage (measured by SonarQube)

```typescript
// Button.test.ts
import { render } from '@testing-library/svelte';
import Button from './Button.svelte';

describe('Button', () => {
  it('renders with correct text', () => {
    const { getByText } = render(Button, { props: { text: 'Click me' } });
    expect(getByText('Click me')).toBeTruthy();
  });
});
```

## Documentation

- Update README.md if adding new features
- Add JSDoc comments for exported functions
- Update SUBMODULES.md if changing package structure
- Include examples in comments

```typescript
/**
 * Validate JWT token
 * @param token - JWT token string
 * @returns User ID if valid, null if expired/invalid
 * @example
 * const userId = validateToken('eyJhb...');
 */
export function validateToken(token: string): string | null {
  // ...
}
```

## Design System Changes

When modifying `packages/design-system/`:

1. Update component in `src/components/`
2. Update Storybook story in `stories/`
3. Update `CHANGELOG.md` with version bump
4. Publish new version: `npm publish --workspace=design-system`

## Git Workflow

```bash
# Update develop branch
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/my-feature

# Make changes, commit
git add .
git commit -m "feat(scope): description"

# Push to remote
git push -u origin feature/my-feature

# On GitHub: Open PR to develop

# After approval: merge
git checkout develop
git pull origin develop
git merge feature/my-feature
git push origin develop

# Delete feature branch
git branch -d feature/my-feature
git push origin --delete feature/my-feature
```

## Quality Standards

- ✅ All tests pass
- ✅ No ESLint warnings
- ✅ TypeScript strict mode passes
- ✅ SonarQube quality gate passes
- ✅ Code coverage ≥ 70%
- ✅ At least 1 review approval

## Common Issues

### Port already in use
```bash
lsof -i :3000 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

### Pre-commit hook failing
```bash
npm run lint      # Fix linting errors
npm run format    # Auto-format code
npm run test      # Run tests
```

### Merge conflicts
```bash
git fetch origin
git merge origin/develop
# Resolve conflicts manually
git add .
git commit -m "fix: resolve merge conflicts"
git push
```

## Getting Help

- Ask in PR comments
- Create issues for bugs/features
- Check ARCHITECTURE.md for design decisions
- Read DEVELOPMENT.md for setup help

## Recognition

Contributors are recognized in:
- Commit history
- Release notes
- CONTRIBUTORS.md (if created)

Thank you for contributing! 🎉
