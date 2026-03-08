import { test, expect } from '@playwright/test';

/**
 * E2E Tests: Profile Endpoint (Protected Route)
 * Covers: GET /api/profile with JWT authentication
 */

test.describe('Profile Endpoint', () => {
  /**
   * Test: Get profile with valid JWT token
   */
  test('should return profile with valid JWT token', async ({ page }) => {
    // First, login to get a token
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        email: 'test@example.com',
        password: 'SecurePass123!'
      }
    });

    expect(loginResponse.status()).toBe(200);
    const loginData = await loginResponse.json();
    const token = loginData.token;

    // Now fetch profile with token
    const profileResponse = await page.request.get('/api/profile', {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });

    expect(profileResponse.status()).toBe(200);
    const profileData = await profileResponse.json();

    expect(profileData).toHaveProperty('id');
    expect(profileData).toHaveProperty('email');
    expect(profileData.email).toBe('test@example.com');
    expect(profileData).toHaveProperty('name');
    expect(profileData).toHaveProperty('roles');
    expect(Array.isArray(profileData.roles)).toBe(true);
    expect(profileData.roles).toContain('USER');
  });

  /**
   * Test: Reject profile request without authentication header
   */
  test('should reject profile access without authentication header', async ({ page }) => {
    const profileResponse = await page.request.get('/api/profile');

    expect(profileResponse.status()).toBe(401);
    const errorData = await profileResponse.json();
    expect(errorData).toHaveProperty('error');
  });

  /**
   * Test: Reject profile request with invalid token format
   */
  test('should reject profile request with invalid token format', async ({ page }) => {
    const profileResponse = await page.request.get('/api/profile', {
      headers: {
        Authorization: 'Bearer invalid-token-format'
      }
    });

    expect(profileResponse.status()).toBe(401);
    const errorData = await profileResponse.json();
    expect(errorData).toHaveProperty('error');
  });

  /**
   * Test: Reject profile request with malformed Authorization header
   */
  test('should reject profile request with malformed Authorization header', async ({ page }) => {
    const profileResponse = await page.request.get('/api/profile', {
      headers: {
        Authorization: 'InvalidFormat token'
      }
    });

    expect(profileResponse.status()).toBe(401);
    const errorData = await profileResponse.json();
    expect(errorData).toHaveProperty('error');
  });

  /**
   * Test: Profile response includes all user details
   */
  test('should include all user details in profile response', async ({ page }) => {
    // Register new user first
    const registerResponse = await page.request.post('/api/auth?action=register', {
      data: {
        email: 'newprofileuser@example.com',
        password: 'SecurePass123!',
        name: 'Profile Test User'
      }
    });

    expect(registerResponse.status()).toBe(201);
    const registerData = await registerResponse.json();
    const token = registerData.token;

    // Fetch profile
    const profileResponse = await page.request.get('/api/profile', {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });

    expect(profileResponse.status()).toBe(200);
    const profileData = await profileResponse.json();

    // Verify all expected fields
    expect(profileData.id).toBeTruthy();
    expect(profileData.email).toBe('newprofileuser@example.com');
    expect(profileData.name).toBe('Profile Test User');
    expect(Array.isArray(profileData.roles)).toBe(true);
    expect(profileData.roles.length).toBeGreaterThan(0);

    // Profile should include timestamps
    expect(profileData).toHaveProperty('createdAt');
    expect(typeof profileData.createdAt).toBe('string');
  });

  /**
   * Test: Multiple sequential profile requests with same token
   */
  test('should allow multiple sequential profile requests with same token', async ({ page }) => {
    // Login
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        email: 'test@example.com',
        password: 'SecurePass123!'
      }
    });

    const loginData = await loginResponse.json();
    const token = loginData.token;

    // First request
    const profile1 = await page.request.get('/api/profile', {
      headers: { Authorization: `Bearer ${token}` }
    });
    expect(profile1.status()).toBe(200);

    // Second request with same token
    const profile2 = await page.request.get('/api/profile', {
      headers: { Authorization: `Bearer ${token}` }
    });
    expect(profile2.status()).toBe(200);

    // Both should return same user data
    const data1 = await profile1.json();
    const data2 = await profile2.json();
    expect(data1.id).toBe(data2.id);
    expect(data1.email).toBe(data2.email);
  });

  /**
   * Test: Profile request with expired token (if expiration is implemented)
   */
  test('should reject profile request with expired token', async ({ page }) => {
    // Create a token that's already expired (or use a mock expired token)
    const expiredToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6MTYwMDAwMDAwMH0.invalid';

    const profileResponse = await page.request.get('/api/profile', {
      headers: {
        Authorization: `Bearer ${expiredToken}`
      }
    });

    // Should return 401 Unauthorized
    expect(profileResponse.status()).toBe(401);
    const errorData = await profileResponse.json();
    expect(errorData).toHaveProperty('error');
  });

  /**
   * Test: Case sensitivity of Authorization header
   */
  test('should require case-sensitive Bearer prefix', async ({ page }) => {
    // Login to get valid token
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        email: 'test@example.com',
        password: 'SecurePass123!'
      }
    });

    const loginData = await loginResponse.json();
    const token = loginData.token;

    // Try with lowercase 'bearer' (should fail)
    const profileResponse = await page.request.get('/api/profile', {
      headers: {
        Authorization: `bearer ${token}`
      }
    });

    expect(profileResponse.status()).toBe(401);
  });
});

/**
 * E2E Tests: Authentication Flow Integration
 * Covers: Full workflow from login to profile access
 */
test.describe('Authentication Flow Integration', () => {
  /**
   * Test: Complete flow - Register → Login → Access Profile
   */
  test('should complete full authentication flow: register -> login -> profile', async ({ page }) => {
    const testEmail = `flow-test-${Date.now()}@example.com`;
    const testPassword = 'FlowTest123!';
    const testName = 'Flow Test User';

    // Step 1: Register
    const registerResponse = await page.request.post('/api/auth?action=register', {
      data: {
        email: testEmail,
        password: testPassword,
        name: testName
      }
    });

    expect(registerResponse.status()).toBe(201);
    const registerData = await registerResponse.json();
    expect(registerData).toHaveProperty('token');
    const registrationToken = registerData.token;

    // Step 2: Access profile with registration token
    const profileAfterRegister = await page.request.get('/api/profile', {
      headers: {
        Authorization: `Bearer ${registrationToken}`
      }
    });

    expect(profileAfterRegister.status()).toBe(200);
    let profileData = await profileAfterRegister.json();
    expect(profileData.email).toBe(testEmail);
    expect(profileData.name).toBe(testName);

    // Step 3: Login with registered credentials
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        email: testEmail,
        password: testPassword
      }
    });

    expect(loginResponse.status()).toBe(200);
    const loginData = await loginResponse.json();
    expect(loginData).toHaveProperty('token');
    const loginToken = loginData.token;

    // Step 4: Access profile with login token
    const profileAfterLogin = await page.request.get('/api/profile', {
      headers: {
        Authorization: `Bearer ${loginToken}`
      }
    });

    expect(profileAfterLogin.status()).toBe(200);
    profileData = await profileAfterLogin.json();
    expect(profileData.email).toBe(testEmail);
    expect(profileData.name).toBe(testName);
  });

  /**
   * Test: Failed login prevents profile access with wrong token
   */
  test('should prevent profile access after failed login attempt', async ({ page }) => {
    // Try to login with wrong password
    const loginResponse = await page.request.post('/api/auth?action=login', {
      data: {
        email: 'test@example.com',
        password: 'WrongPassword123!'
      }
    });

    expect(loginResponse.status()).toBe(401);
    const errorData = await loginResponse.json();
    expect(errorData).not.toHaveProperty('token');

    // Try to access profile without valid token
    const profileResponse = await page.request.get('/api/profile', {
      headers: {
        Authorization: 'Bearer fake-token-from-failed-login'
      }
    });

    expect(profileResponse.status()).toBe(401);
  });

  /**
   * Test: Concurrent authentication requests
   */
  test('should handle concurrent authentication requests', async ({ page }) => {
    // Make multiple concurrent login requests
    const results = await Promise.all([
      page.request.post('/api/auth?action=login', {
        data: { email: 'test@example.com', password: 'SecurePass123!' }
      }),
      page.request.post('/api/auth?action=login', {
        data: { email: 'test@example.com', password: 'SecurePass123!' }
      }),
      page.request.post('/api/auth?action=login', {
        data: { email: 'test@example.com', password: 'SecurePass123!' }
      })
    ]);

    // All should succeed
    for (const result of results) {
      expect(result.status()).toBe(200);
      const data = await result.json();
      expect(data).toHaveProperty('token');
    }
  });
});
