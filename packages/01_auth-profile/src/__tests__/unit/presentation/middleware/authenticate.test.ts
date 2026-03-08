import { describe, it, expect, beforeEach, vi } from 'vitest';
import { createAuthenticateMiddleware, extractAuthHeader } from '../../../../presentation/middleware/authenticate';
import type { ITokenGenerator } from '../../../../application/ports/ITokenGenerator';

describe('Authentication Middleware', () => {
  let tokenGenerator: ITokenGenerator;
  let authenticate: ReturnType<typeof createAuthenticateMiddleware>;

  beforeEach(() => {
    tokenGenerator = {
      generate: vi.fn(),
      verify: vi.fn(),
      decode: vi.fn(),
      isExpired: vi.fn()
    };

    authenticate = createAuthenticateMiddleware(tokenGenerator);
  });

  describe('createAuthenticateMiddleware', () => {
    it('should return null when no auth header', () => {
      const result = authenticate(undefined);

      expect(result).toBeNull();
    });

    it('should return null for invalid bearer format', () => {
      const result = authenticate('Invalid header');

      expect(result).toBeNull();
    });

    it('should return null when token is expired', () => {
      const token = 'mock-token';
      const authHeader = `Bearer ${token}`;

      vi.mocked(tokenGenerator.isExpired).mockReturnValue(true);

      const result = authenticate(authHeader);

      expect(result).toBeNull();
    });

    it('should return userId on valid token', () => {
      const token = 'mock-token';
      const authHeader = `Bearer ${token}`;
      const userId = '550e8400-e29b-41d4-a716-446655440000';

      vi.mocked(tokenGenerator.isExpired).mockReturnValue(false);
      vi.mocked(tokenGenerator.decode).mockReturnValue({
        userId,
        email: 'test@example.com',
        roles: ['USER']
      });

      const result = authenticate(authHeader);

      expect(result).not.toBeNull();
      expect(result?.userId).toBe(userId);
    });

    it('should return null when decode fails', () => {
      const token = 'invalid-token';
      const authHeader = `Bearer ${token}`;

      vi.mocked(tokenGenerator.isExpired).mockReturnValue(false);
      vi.mocked(tokenGenerator.decode).mockImplementation(() => {
        throw new Error('Decode failed');
      });

      const result = authenticate(authHeader);

      expect(result).toBeNull();
    });

    it('should return null when userId is missing from payload', () => {
      const token = 'mock-token';
      const authHeader = `Bearer ${token}`;

      vi.mocked(tokenGenerator.isExpired).mockReturnValue(false);
      vi.mocked(tokenGenerator.decode).mockReturnValue({
        email: 'test@example.com',
        roles: ['USER']
      } as any);

      const result = authenticate(authHeader);

      expect(result).toBeNull();
    });

    it('should extract token correctly from Bearer format', () => {
      const token = 'mock-token-value';
      const authHeader = `Bearer ${token}`;

      vi.mocked(tokenGenerator.isExpired).mockReturnValue(false);
      vi.mocked(tokenGenerator.decode).mockReturnValue({
        userId: 'user-id',
        email: 'test@example.com',
        roles: ['USER']
      });

      authenticate(authHeader);

      // Verify that the middleware was called with proper token handling
      expect(tokenGenerator.isExpired).toHaveBeenCalled();
    });

    it('should handle case-sensitive Bearer prefix', () => {
      const token = 'mock-token';
      const authHeader = `bearer ${token}`;

      const result = authenticate(authHeader);

      expect(result).toBeNull();
    });
  });

  describe('extractAuthHeader', () => {
    it('should extract Authorization header from request', () => {
      const headerValue = 'Bearer mock-token';
      const request = new Request('http://localhost', {
        headers: { Authorization: headerValue }
      });

      const result = extractAuthHeader(request);

      expect(result).toBe(headerValue);
    });

    it('should return undefined when no Authorization header', () => {
      const request = new Request('http://localhost', {
        headers: {}
      });

      const result = extractAuthHeader(request);

      expect(result).toBeUndefined();
    });
  });
});
