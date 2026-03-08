import { test as base, Page } from '@playwright/test';

/**
 * Custom fixtures for E2E tests
 * Provides reusable test utilities and authenticated contexts
 */

interface AuthContext {
  page: Page;
  token: string;
  userId: string;
  email: string;
  login(email: string, password: string): Promise<void>;
  register(email: string, password: string, name: string): Promise<void>;
}

/**
 * Custom test fixture: authenticated user
 * Automatically logs in user before each test
 */
export const test = base.extend<{ authenticatedUser: AuthContext }>({
  authenticatedUser: async ({ page }, use) => {
    const context: AuthContext = {
      page,
      token: '',
      userId: '',
      email: 'test@example.com',

      /**
       * Helper: Login and store token
       */
      async login(email: string, password: string) {
        const response = await page.request.post('/api/auth?action=login', {
          data: { email, password }
        });

        if (response.status() !== 200) {
          throw new Error(`Login failed: ${response.status()}`);
        }

        const data = await response.json();
        context.token = data.token;
        context.userId = data.user.id;
        context.email = email;
      },

      /**
       * Helper: Register and login
       */
      async register(email: string, password: string, name: string) {
        const response = await page.request.post('/api/auth?action=register', {
          data: { email, password, name }
        });

        if (response.status() !== 201) {
          throw new Error(`Registration failed: ${response.status()}`);
        }

        const data = await response.json();
        context.token = data.token;
        context.userId = data.user.id;
        context.email = email;
      }
    };

    // Pre-login for tests that need authenticated user
    await context.login('test@example.com', 'SecurePass123!');

    await use(context);
  }
});

export { expect } from '@playwright/test';

/**
 * Test data generators
 */
export const testData = {
  /**
   * Generate unique email for test isolation
   */
  uniqueEmail(prefix = 'test'): string {
    return `${prefix}-${Date.now()}-${Math.random().toString(36).substring(7)}@example.com`;
  },

  /**
   * Generate unique username
   */
  uniqueUsername(prefix = 'user'): string {
    return `${prefix}-${Date.now()}`;
  },

  /**
   * Standard test credentials
   */
  validCredentials: {
    email: 'test@example.com',
    password: 'SecurePass123!',
    name: 'Test User'
  },

  /**
   * Invalid test credentials
   */
  invalidCredentials: {
    weakPassword: 'weak',
    invalidEmail: 'not-an-email',
    emptyEmail: '',
    emptyPassword: '',
    emptyName: ''
  }
};

/**
 * API helper functions
 */
export const apiHelpers = {
  /**
   * Make authenticated request with Bearer token
   */
  async authenticatedRequest(
    page: Page,
    method: 'GET' | 'POST' | 'PUT' | 'DELETE',
    endpoint: string,
    token: string,
    data?: unknown
  ) {
    const options: Parameters<typeof page.request.post>[1] = {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    };

    if (data) {
      options.data = data;
    }

    switch (method) {
      case 'GET':
        return page.request.get(endpoint, options);
      case 'POST':
        return page.request.post(endpoint, options);
      case 'PUT':
        return page.request.put(endpoint, options);
      case 'DELETE':
        return page.request.delete(endpoint, options);
    }
  },

  /**
   * Login and return token
   */
  async login(
    page: Page,
    email: string,
    password: string
  ): Promise<{ token: string; userId: string }> {
    const response = await page.request.post('/api/auth?action=login', {
      data: { email, password }
    });

    if (response.status() !== 200) {
      throw new Error(`Login failed: ${response.status()}`);
    }

    const data = await response.json();
    return {
      token: data.token,
      userId: data.user.id
    };
  },

  /**
   * Register and return token
   */
  async register(
    page: Page,
    email: string,
    password: string,
    name: string
  ): Promise<{ token: string; userId: string }> {
    const response = await page.request.post('/api/auth?action=register', {
      data: { email, password, name }
    });

    if (response.status() !== 201) {
      throw new Error(`Registration failed: ${response.status()}`);
    }

    const data = await response.json();
    return {
      token: data.token,
      userId: data.user.id
    };
  },

  /**
   * Get profile with token
   */
  async getProfile(page: Page, token: string) {
    const response = await page.request.get('/api/profile', {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });

    if (response.status() !== 200) {
      throw new Error(`Get profile failed: ${response.status()}`);
    }

    return response.json();
  }
};

/**
 * Assertion helpers
 */
export const assertions = {
  /**
   * Assert valid JWT token structure
   */
  isValidJWT(token: string): boolean {
    const parts = token.split('.');
    if (parts.length !== 3) return false;

    // Each part should be base64url encoded
    const base64urlRegex = /^[A-Za-z0-9_-]+$/;
    return parts.every(part => base64urlRegex.test(part));
  },

  /**
   * Assert valid login response
   */
  assertValidLoginResponse(data: unknown) {
    const loginData = data as any;

    if (!loginData.token) throw new Error('Missing token in login response');
    if (!this.isValidJWT(loginData.token)) throw new Error('Invalid JWT format');
    if (!loginData.user) throw new Error('Missing user in login response');
    if (!loginData.user.id) throw new Error('Missing user.id');
    if (!loginData.user.email) throw new Error('Missing user.email');
    if (!Array.isArray(loginData.user.roles)) throw new Error('Invalid user.roles');
  },

  /**
   * Assert valid profile response
   */
  assertValidProfileResponse(data: unknown) {
    const profile = data as any;

    if (!profile.id) throw new Error('Missing id in profile');
    if (!profile.email) throw new Error('Missing email in profile');
    if (!profile.name) throw new Error('Missing name in profile');
    if (!Array.isArray(profile.roles)) throw new Error('Invalid roles in profile');
    if (!profile.createdAt) throw new Error('Missing createdAt in profile');
    if (typeof profile.createdAt !== 'string') throw new Error('Invalid createdAt format');
  }
};
