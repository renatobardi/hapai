# OUTE Project - Quality Standards

## Overview

This document outlines the **mandatory quality gates** enforced on all pull requests to ensure code excellence, security, and maintainability.

**Status**: ✅ ENFORCED (All-at-once rollout)
**Last Updated**: 2026-03-08

---

## Quality Gates

### 1. Code Quality & Formatting ✅

**Tools**: ESLint, Prettier, TypeScript

**Requirements**:
- ✅ Zero ESLint errors (`npm run lint`)
- ✅ Code properly formatted with Prettier (`npm run format`)
- ✅ TypeScript strict mode passes (`tsc --noEmit`)
- ✅ No `@typescript-eslint/no-explicit-any` violations
- ✅ No console statements in production code
- ✅ No `var` declarations (must use `const`/`let`)

**How to Fix Locally**:
```bash
npm run lint --fix        # Auto-fix ESLint issues
npm run format            # Auto-format code with Prettier
npm run typecheck         # Check TypeScript errors
```

---

### 2. Test Coverage 🧪

**Tool**: Vitest with coverage reporting

**Requirements**:
- ✅ **80% line coverage minimum**
- ✅ **75% branch coverage minimum**
- ✅ **80% function coverage minimum**
- ✅ **80% statement coverage minimum**
- ✅ All 4 packages must have test files (*.test.ts)
- ✅ Coverage reports generated in `coverage/` directory

**How to Run Tests Locally**:
```bash
npm run test              # Run all tests
npm run test -- --coverage    # Run tests with coverage report
npm run test -- --ui      # Run with UI visualization
```

**Coverage Report Locations**:
- HTML Report: `coverage/index.html`
- LCOV Report: `coverage/lcov.info` (used by SonarQube)

**Packages Status**:
- ✅ `01_auth-profile` - Configured, has tests
- ✅ `00_dashboard` - New vitest.config.ts, needs tests
- ✅ `02_projects` - New vitest.config.ts, needs tests
- ✅ `design-system` - New vitest.config.ts, needs tests

---

### 3. SonarQube Quality Gate 🔍

**Status**: ✅ **REQUIRED** (not optional)

**Requirements** (SonarQube must pass):
- ✅ **Security Rating: A** (zero critical/high vulnerabilities)
- ✅ **Reliability Rating: A** (zero bugs)
- ✅ **Maintainability Rating: A** (code quality)
- ✅ **Overall Grade: A- or better** (cannot be B/C/D/E)
- ✅ **Code Coverage: 80%+** (integrated with Vitest)
- ✅ **Code Duplication: < 3%**
- ✅ **Critical Code Smells: 0**
- ✅ **Blocker Violations: 0**
- ✅ **Vulnerabilities: 0**
- ✅ **Security Hotspots: 100% reviewed**

**Configuration**:
- Config file: `.sonarcloud.yml`
- Workflow: `.github/workflows/1-pull-request.yml`
- Coverage source: `coverage/lcov.info`

**What Blocks a PR**:
- ❌ Grade below A-
- ❌ Any vulnerability (CRITICAL/HIGH)
- ❌ Coverage below 80%
- ❌ Critical code smells
- ❌ SonarQube analysis skipped (token required)

---

### 4. Security Checks 🔐

#### 4.1 Dependency Vulnerabilities

**Tool**: npm audit + OWASP Dependency Check

**Requirements**:
- ✅ **No CRITICAL vulnerabilities** (blocks PR)
- ✅ **No HIGH vulnerabilities** (blocks PR)
- ⚠️ MODERATE vulnerabilities allowed (needs discussion)
- ℹ️ LOW vulnerabilities are informational

**Workflow**: `.github/workflows/6-dependency-check.yml`

**How to Check Locally**:
```bash
npm audit                 # Check for vulnerabilities
npm audit fix             # Auto-fix fixable issues
npm audit fix --force     # Force fix (may break compatibility)
```

**What to Do if Blocked**:
1. Check `npm audit` output for details
2. Try `npm audit fix` to auto-patch
3. If not fixable, you may need to:
   - Update the dependency version manually
   - Wait for dependency maintainer to release a patch
   - Suppress with SonarQube if it's a false positive

#### 4.2 Secret Scanning

**Tool**: TruffleHog + git-secrets

**Checks**:
- ✅ No hardcoded API keys, passwords, tokens
- ✅ No private credentials in code
- ✅ No AWS/GCP/Azure keys

**If Blocked**:
1. Remove the secret from code
2. Rotate the credential (if it was real)
3. Use environment variables instead

#### 4.3 Container Image Scanning

**Tool**: Trivy

**Requirements**:
- ✅ No CRITICAL vulnerabilities in Docker images
- ⚠️ HIGH vulnerabilities need review

---

### 5. Docker Build Verification 🐳

**Requirements**:
- ✅ All 4 packages must build successfully
- ✅ No build errors or warnings

**Packages**:
- `design-system`
- `00_dashboard`
- `01_auth-profile`
- `02_projects`

**How to Test Locally**:
```bash
docker build -f packages/00_dashboard/Dockerfile .
docker build -f packages/01_auth-profile/Dockerfile .
docker build -f packages/02_projects/Dockerfile .
docker build -f packages/design-system/Dockerfile .
```

---

## PR Workflow

### Full Quality Gate Sequence

```
1. Checkout code
2. Setup Node.js 20
3. Install dependencies
   ↓
4. ESLint check         (parallel)
5. Prettier format      (parallel)
6. TypeScript check     (parallel)
7. Unit tests + coverage (parallel)
8. Docker build         (parallel)
   ↓
9. SonarQube scan       (must pass 80%+ coverage, A- grade)
   ↓
10. npm audit security  (fail on HIGH/CRITICAL)
    ↓
11. PR Summary          (fail if any check failed)
    ↓
✅ PR can be merged only if ALL checks pass
```

### PR Requirements Checklist

Before requesting review:

- [ ] `npm run lint` passes (no errors)
- [ ] `npm run format --check` passes
- [ ] `npm run typecheck` passes
- [ ] `npm run test -- --coverage` shows 80%+ coverage
- [ ] `npm audit` shows no HIGH/CRITICAL vulnerabilities
- [ ] SonarQube quality gate would pass (estimated)
- [ ] Docker builds succeed for your package

---

## Common Issues & Solutions

### ❌ "Coverage below 80%"
**Fix**: Write more tests for untested code paths
```bash
npm run test -- --coverage    # See which lines are uncovered
npm run test -- --ui          # Visualize coverage
```

### ❌ "SonarQube skipped - SONAR_TOKEN required"
**Fix**: Set `SONAR_TOKEN` secret in GitHub repository settings
- Contact repository admin if you don't have access
- Required for all PRs (not optional)

### ❌ "HIGH vulnerability in dependency X"
**Fix**: Update or patch the dependency
```bash
npm audit fix --save
npm update package-name
```

### ❌ "@typescript-eslint/no-explicit-any error"
**Fix**: Use proper type annotations instead of `any`
```typescript
// ❌ Bad
const value: any = getSomeValue()

// ✅ Good
const value: SomeType = getSomeValue()
const value: unknown = getSomeValue()  // if type is truly unknown
```

### ❌ "Code duplication > 3%"
**Fix**: Extract duplicated code into shared utilities
- Create utility functions in `shared/` package
- Reuse components from `design-system`
- Use shared types/interfaces

---

## Quality Standards by Package

### 01_auth-profile
- ✅ Tests: Configured and running
- ✅ Coverage: Already has unit tests
- 📋 E2E Tests: Planned (critical path for auth)

### 00_dashboard
- ✅ Vitest config: Created
- 📋 Tests: Need to be implemented
- 📋 Coverage: Target 80%

### 02_projects
- ✅ Vitest config: Created
- 📋 Tests: Need to be implemented
- 📋 Coverage: Target 80%

### design-system
- ✅ Vitest config: Created
- ✅ Storybook: Already has stories
- 📋 Tests: Need unit tests for components
- 📋 Coverage: Target 80%

---

## E2E Testing (Phase 1)

**Tool**: Playwright

**Critical Paths to Test**:
1. **Auth Flow**: Login/logout
2. **Dashboard**: Page loads, data displays
3. **Projects**: Create/read/update/delete
4. **Design System**: Components render correctly

**Status**: Implementation in progress

---

## Local Development Setup

### Quick Check Before Pushing

```bash
# 1. Format & lint
npm run format
npm run lint

# 2. Type check
npm run typecheck

# 3. Run tests with coverage
npm run test -- --coverage

# 4. Check for vulnerabilities
npm audit

# 5. Build Docker images
docker build -f packages/00_dashboard/Dockerfile .
docker build -f packages/01_auth-profile/Dockerfile .
docker build -f packages/02_projects/Dockerfile .
docker build -f packages/design-system/Dockerfile .
```

### Pre-Push Script

Create `.git/hooks/pre-push` to run checks automatically:

```bash
#!/bin/bash
set -e

echo "Running quality checks..."
npm run lint
npm run format -- --check
npm run typecheck
npm run test -- --coverage

echo "✅ All checks passed!"
```

---

## Success Metrics

After implementing these standards:

| Metric | Target | Current |
|--------|--------|---------|
| Code Coverage | 80%+ | TBD |
| SonarQube Grade | A- or better | TBD |
| Security Vulnerabilities | 0 (HIGH+CRITICAL) | TBD |
| Code Duplication | < 3% | TBD |
| Blocker Issues | 0 | TBD |
| Test Execution Time | < 5 min | TBD |

---

## Enforcement Strategy

**Status**: ✅ ALL-AT-ONCE (rigorous)

- **No grace period**: All gates enforced immediately
- **No bypasses**: All checks must pass
- **Required token**: SonarQube token is mandatory
- **Blocking**: PRs fail if any gate doesn't pass

---

## Contact & Questions

For questions about quality standards:
- Check this document first
- Open an issue in the repository
- Contact the project lead

---

**Last Update**: 2026-03-08
**Version**: 1.0 - Initial Rollout
