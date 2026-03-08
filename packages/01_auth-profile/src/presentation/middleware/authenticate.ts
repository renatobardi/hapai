import type { ITokenGenerator } from '../../application/ports/ITokenGenerator';

/**
 * Middleware: Authenticate
 * Validates JWT token from Authorization header
 * Extracts and returns user ID if valid
 */
export function createAuthenticateMiddleware(tokenGenerator: ITokenGenerator) {
  return function authenticate(
    authHeader?: string
  ): { userId: string } | null {
    // Step 1: Check if authorization header exists
    if (!authHeader) {
      return null;
    }

    // Step 2: Extract token from "Bearer <token>" format
    if (!authHeader.startsWith('Bearer ')) {
      return null;
    }

    const token = authHeader.slice(7); // Remove "Bearer " prefix

    // Step 3: Check if token is expired
    if (tokenGenerator.isExpired(token)) {
      return null;
    }

    // Step 4: Verify token and extract payload
    try {
      const payload = tokenGenerator.decode(token);
      if (!payload || !payload.userId) {
        return null;
      }

      return { userId: payload.userId };
    } catch {
      return null;
    }
  };
}

/**
 * Helper to extract Authorization header from request
 */
export function extractAuthHeader(request: Request): string | undefined {
  return request.headers.get('Authorization') ?? undefined;
}
