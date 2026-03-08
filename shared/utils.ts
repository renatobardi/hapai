/**
 * Shared utilities for OUTE
 */

/**
 * Format date as ISO string
 */
export function formatDate(date: Date): string {
  return date.toISOString();
}

/**
 * Parse JWT payload without verification (for client-side)
 * WARNING: Always verify on server!
 */
export function parseJWT(token: string): Record<string, any> | null {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    return JSON.parse(jsonPayload);
  } catch {
    return null;
  }
}

/**
 * Check if JWT token is expired
 */
export function isTokenExpired(token: string): boolean {
  const payload = parseJWT(token);
  if (!payload) return true;

  const expiryTime = payload.exp * 1000; // convert to milliseconds
  return Date.now() >= expiryTime;
}

/**
 * Build API URL
 */
export function buildApiUrl(baseUrl: string, path: string): string {
  return `${baseUrl.replace(/\/$/, '')}/${path.replace(/^\//, '')}`;
}

/**
 * Format error message
 */
export function formatErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  return 'An unknown error occurred';
}

/**
 * Validate email
 */
export function isValidEmail(email: string): boolean {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
}

/**
 * Validate password strength
 */
export function isValidPassword(password: string): boolean {
  return password.length >= 8;
}

/**
 * Debounce function
 */
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: ReturnType<typeof setTimeout>;

  return function executedFunction(...args: Parameters<T>) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };

    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

/**
 * Sleep utility
 */
export async function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
