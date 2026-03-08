# E2E Tests - Auth Profile Service

## Overview

End-to-end tests for the authentication and profile management service using **Playwright**.

### Test Files

- **`auth.spec.ts`** - Authentication flows (login, register, token validation)
  - 8 test cases
  - Coverage: Login success/failures, registration, JWT validation

- **`profile.spec.ts`** - Profile endpoint (protected routes) + full integration flows
  - 13 test cases
  - Coverage: Protected routes, authentication headers, complete flows

**Total: 21 E2E tests**

## Setup

### Prerequisites

1. Node.js v20+
2. npm workspaces installed
3. PostgreSQL running (or mock adapter configured)
4. SvelteKit dev server running on `http://localhost:5173`

### Installation

```bash
cd packages/01_auth-profile

# Install Playwright (if not already installed)
npm install -D @playwright/test

# Install other E2E testing dependencies
npm install -D playwright
```

### Configuration

The Playwright configuration is in `playwright.config.ts`:

```typescript
// Key settings:
// - baseURL: http://localhost:5173
// - webServer: auto-starts SvelteKit dev server
// - browser: chromium
// - reporter: html
```

## Running Tests

### Start the Dev Server (if not running)

```bash
npm run dev
```

The dev server will start on `http://localhost:5173` and auto-reload on file changes.

### Run All E2E Tests

```bash
npm run test:e2e
```

### Run Specific Test File

```bash
npx playwright test auth.spec.ts
npx playwright test profile.spec.ts
```

### Run Specific Test Case

```bash
npx playwright test -g "should login successfully with valid credentials"
npx playwright test -g "Profile Endpoint"
```

### Run in Watch Mode (Development)

```bash
npx playwright test --watch
```

### Run in UI Mode (Interactive)

```bash
npx playwright test --ui
```

This opens an interactive debugger where you can:
- Step through tests
- Inspect network requests
- View snapshots
- Pause/resume execution

### Run in Debug Mode

```bash
npx playwright test --debug
```

This opens Inspector with full debugging capabilities.

### Run with Verbose Output

```bash
npx playwright test --reporter=verbose
```

## Viewing Test Reports

After running tests, view the HTML report:

```bash
npx playwright show-report
```

This opens an interactive report showing:
- Test results (passed/failed)
- Screenshot comparisons
- Video recordings (if enabled)
- Execution timeline

## Test Structure

### Authentication Tests (`auth.spec.ts`)

#### Login Tests
1. ✅ Login with valid credentials → 200 + token
2. ❌ Login with invalid email format → 400
3. ❌ Login with incorrect password → 401
4. ❌ Login with missing email → 400

#### Registration Tests
5. ✅ Register with valid data → 201 + token
6. ❌ Register with weak password → 400
7. ❌ Register with invalid email → 400
8. ❌ Register with missing fields → 400

#### Token Validation
9. ✅ JWT token has valid 3-part structure (header.payload.signature)

### Profile Tests (`profile.spec.ts`)

#### Protected Route Tests
1. ✅ Get profile with valid JWT → 200 + user data
2. ❌ Get profile without auth header → 401
3. ❌ Get profile with invalid token → 401
4. ❌ Get profile with malformed header → 401
5. ✅ Profile includes all user details (id, email, name, roles, timestamps)
6. ✅ Multiple sequential requests with same token
7. ❌ Profile access with expired token → 401
8. ❌ Case-sensitive Bearer prefix check

#### Full Integration Flows
9. ✅ Register → Login → Profile access (complete flow)
10. ❌ Failed login prevents profile access
11. ✅ Concurrent authentication requests handled

## Key Test Scenarios

### Success Scenarios ✅

```typescript
// Login & get profile
POST /api/auth?action=login { email, password }
  → 200 + { token, user }

GET /api/profile (Authorization: Bearer <token>)
  → 200 + { id, email, name, roles, createdAt, lastLogin }

// Register & get profile
POST /api/auth?action=register { email, password, name }
  → 201 + { token, user }

GET /api/profile (Authorization: Bearer <token>)
  → 200 + user data
```

### Error Scenarios ❌

```typescript
// No auth header
GET /api/profile
  → 401 + { error }

// Invalid token
GET /api/profile (Authorization: Bearer invalid)
  → 401 + { error }

// Malformed header
GET /api/profile (Authorization: InvalidFormat token)
  → 401 + { error }

// Case sensitivity
GET /api/profile (Authorization: bearer <token>)  // lowercase
  → 401 + { error }

// Expired token
GET /api/profile (Authorization: Bearer <expired-token>)
  → 401 + { error }
```

## Testing Best Practices

### 1. Use Unique Test Data

Tests use `Date.now()` for unique emails:

```typescript
const testEmail = `flow-test-${Date.now()}@example.com`;
```

This prevents conflicts when running tests multiple times.

### 2. Test Isolation

Each test is independent:
- No shared state
- Register/login within each test
- No test dependencies

### 3. Comprehensive Error Scenarios

Tests cover:
- Happy path (success)
- Missing required fields
- Invalid formats
- Authentication failures
- Security checks (case sensitivity, token format)

### 4. Full Integration Testing

`profile.spec.ts` includes complete workflows:
- Register → Login → Profile (validates entire flow)
- Concurrent requests (validates system stability)

## Common Issues & Solutions

### Issue: `Target page, context or browser has been closed`

**Cause**: Dev server not running or wrong baseURL

**Solution**:
```bash
npm run dev  # Start dev server first
npm run test:e2e  # Then run tests
```

### Issue: `Timeout waiting for predicate`

**Cause**: Requests taking too long or server unresponsive

**Solution**: Increase timeout in `playwright.config.ts`:
```typescript
expect.setDefaultTimeout(5000);  // 5 seconds
```

### Issue: `Navigation to "http://localhost:5173/" failed`

**Cause**: Dev server not reachable

**Solution**:
```bash
# Verify dev server is running
curl http://localhost:5173
```

### Issue: Tests pass locally but fail in CI

**Cause**: Different environment, different test data

**Solution**:
- Use environment variables for API endpoints
- Don't hardcode localhost URLs
- Use test data seeding in CI

## CI/CD Integration

### GitHub Actions Example

```yaml
name: E2E Tests

on: [pull_request, push]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'

      - run: npm ci
      - run: npm run dev &  # Start dev server
      - run: npm run test:e2e

      - uses: actions/upload-artifact@v3
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

## Performance Considerations

### Test Execution Time

- **auth.spec.ts**: ~5-10 seconds (8 tests)
- **profile.spec.ts**: ~10-15 seconds (13 tests)
- **Total**: ~20-30 seconds

### Parallel Execution

Playwright runs tests in parallel by default:

```bash
npx playwright test --workers=4  # 4 parallel workers
```

To run serially (for debugging):

```bash
npx playwright test --workers=1
```

## Next Steps

### Additional Test Coverage

Consider adding:
- [ ] Token refresh tests
- [ ] Logout functionality tests
- [ ] Role-based access control tests
- [ ] Rate limiting tests
- [ ] CORS validation tests
- [ ] SQL injection prevention tests
- [ ] XSS prevention tests

### Performance Tests

```bash
npx playwright test --reporter=json > results.json
# Analyze response times, throughput
```

### Visual Regression Testing

Add screenshot comparisons:

```typescript
await expect(page).toHaveScreenshot();
```

## Resources

- [Playwright Documentation](https://playwright.dev)
- [Playwright Test](https://playwright.dev/docs/intro)
- [Test Reports](https://playwright.dev/docs/test-reporters)
- [Debugging Guide](https://playwright.dev/docs/debug)

## Troubleshooting

For more help, check:
- `playwright.config.ts` - Playwright configuration
- `.env.example` - Environment variables
- GitHub Actions logs - CI/CD issues
- `npm run test:e2e -- --help` - CLI options
