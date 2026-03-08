import { test, expect } from '@playwright/test';

/**
 * E2E Tests: Authentication Flow
 * Covers: Login, Register, Token handling
 */

test.describe('Authentication Flow', () => {
  /**
   * Test: Login with valid credentials
   */
  test('should login successfully with valid credentials', async ({ page }) => {
    // Navigate to login page (would be in real app)
    await page.goto('/');

    // Make login request to API
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        email: 'test@example.com',
        password: 'SecurePass123!'
      }
    });

    // Verify response status
    expect(loginResponse.status()).toBe(200);

    // Parse response
    const loginData = await loginResponse.json();

    // Verify token exists
    expect(loginData).toHaveProperty('token');
    expect(typeof loginData.token).toBe('string');

    // Verify user data
    expect(loginData).toHaveProperty('user');
    expect(loginData.user.email).toBe('test@example.com');
    expect(loginData.user).toHaveProperty('roles');
    expect(Array.isArray(loginData.user.roles)).toBe(true);
  });

  /**
   * Test: Login with invalid email
   */
  test('should reject login with invalid email format', async ({ page }) => {
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        email: 'invalid-email',
        password: 'SecurePass123!'
      }
    });

    // Should return 400 Bad Request
    expect(loginResponse.status()).toBe(400);

    const errorData = await loginResponse.json();
    expect(errorData).toHaveProperty('error');
    expect(errorData.code).toBe('INVALID_EMAIL');
  });

  /**
   * Test: Login with incorrect password
   */
  test('should reject login with incorrect password', async ({ page }) => {
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        email: 'test@example.com',
        password: 'WrongPassword123!'
      }
    });

    // Should return 401 Unauthorized
    expect(loginResponse.status()).toBe(401);

    const errorData = await loginResponse.json();
    expect(errorData).toHaveProperty('error');
    expect(errorData.error).toContain('Invalid');
  });

  /**
   * Test: Login with missing fields
   */
  test('should reject login with missing email', async ({ page }) => {
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        password: 'SecurePass123!'
      }
    });

    expect(loginResponse.status()).toBe(400);
  });

  /**
   * Test: Register with valid data
   */
  test('should register successfully with valid data', async ({ page }) => {
    const registerResponse = await page.request.post('/api/auth?action=register', {
      data: {
        email: 'newuser@example.com',
        password: 'SecurePass123!',
        name: 'New User'
      }
    });

    // Should return 201 Created
    expect(registerResponse.status()).toBe(201);

    const registerData = await registerResponse.json();

    // Verify token exists
    expect(registerData).toHaveProperty('token');
    expect(typeof registerData.token).toBe('string');

    // Verify user data
    expect(registerData.user.email).toBe('newuser@example.com');
    expect(registerData.user.name).toBe('New User');
    expect(registerData.user.roles).toContain('USER');
  });

  /**
   * Test: Register with weak password
   */
  test('should reject registration with weak password', async ({ page }) => {
    const registerResponse = await page.request.post('/api/auth?action=register', {
      data: {
        email: 'user@example.com',
        password: 'weak', // Too weak
        name: 'User'
      }
    });

    // Should return 400 Bad Request
    expect(registerResponse.status()).toBe(400);

    const errorData = await registerResponse.json();
    expect(errorData.code).toBe('INVALID_PASSWORD');
  });

  /**
   * Test: Register with invalid email
   */
  test('should reject registration with invalid email', async ({ page }) => {
    const registerResponse = await page.request.post('/api/auth?action=register', {
      data: {
        email: 'not-an-email',
        password: 'SecurePass123!',
        name: 'User'
      }
    });

    expect(registerResponse.status()).toBe(400);
    const errorData = await registerResponse.json();
    expect(errorData.code).toBe('INVALID_EMAIL');
  });

  /**
   * Test: Register with missing fields
   */
  test('should reject registration with missing name', async ({ page }) => {
    const registerResponse = await page.request.post('/api/auth?action=register', {
      data: {
        email: 'user@example.com',
        password: 'SecurePass123!'
      }
    });

    expect(registerResponse.status()).toBe(400);
  });

  /**
   * Test: Token format validation
   */
  test('should return valid JWT token format', async ({ page }) => {
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        email: 'test@example.com',
        password: 'SecurePass123!'
      }
    });

    const loginData = await loginResponse.json();
    const token = loginData.token;

    // JWT should have 3 parts separated by dots
    const parts = token.split('.');
    expect(parts.length).toBe(3);

    // Each part should be base64
    expect(parts[0]).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(parts[1]).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(parts[2]).toMatch(/^[A-Za-z0-9_-]+$/);
  });
});
