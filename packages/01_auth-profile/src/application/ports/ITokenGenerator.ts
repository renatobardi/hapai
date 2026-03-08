/**
 * Port: Token Generation
 * Abstracts the token generation mechanism (JWT, etc.)
 */
export interface ITokenGenerator {
  /**
   * Generate an authentication token
   */
  generate(payload: {
    userId: string;
    email: string;
    roles: string[];
  }): Promise<string>;

  /**
   * Verify a token and extract payload
   * Returns null if token is invalid or expired
   */
  verify(token: string): Promise<{
    userId: string;
    email: string;
    roles: string[];
  } | null>;

  /**
   * Decode a token without verification
   * Useful for checking claims without validating signature
   */
  decode(token: string): {
    userId: string;
    email: string;
    roles: string[];
    iat?: number;
    exp?: number;
  } | null;

  /**
   * Check if a token is expired
   */
  isExpired(token: string): boolean;
}
