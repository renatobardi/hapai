/**
 * Client-side authentication utilities for 00_dashboard
 */

import { writable, type Writable } from 'svelte/store';
import type { User } from '@oute/shared';

// Auth token storage key
const TOKEN_KEY = 'oute:auth:token';
const USER_KEY = 'oute:user';

// Auth state store
export const authToken: Writable<string | null> = writable(null);
export const user: Writable<User | null> = writable(null);
export const isAuthenticated: Writable<boolean> = writable(false);

/**
 * Initialize auth from localStorage
 */
export function initializeAuth(): void {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem(TOKEN_KEY);
    const userData = localStorage.getItem(USER_KEY);

    if (token) {
      authToken.set(token);
      isAuthenticated.set(true);

      if (userData) {
        try {
          user.set(JSON.parse(userData));
        } catch {
          console.error('Failed to parse user data');
        }
      }
    }
  }
}

/**
 * Login user
 */
export async function login(email: string, password: string): Promise<void> {
  const authUrl = import.meta.env.VITE_AUTH_SERVICE_URL || 'http://localhost:3001';

  const response = await fetch(`${authUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Login failed');
  }

  const data = await response.json();

  // Store token and user
  localStorage.setItem(TOKEN_KEY, data.token);
  localStorage.setItem(USER_KEY, JSON.stringify(data.user));

  // Update stores
  authToken.set(data.token);
  user.set(data.user);
  isAuthenticated.set(true);
}

/**
 * Logout user
 */
export function logout(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);

  authToken.set(null);
  user.set(null);
  isAuthenticated.set(false);
}

/**
 * Get current token
 */
export function getToken(): string | null {
  if (typeof window !== 'undefined') {
    return localStorage.getItem(TOKEN_KEY);
  }
  return null;
}

/**
 * Get current user
 */
export function getCurrentUser(): User | null {
  if (typeof window !== 'undefined') {
    const userData = localStorage.getItem(USER_KEY);
    if (userData) {
      try {
        return JSON.parse(userData);
      } catch {
        return null;
      }
    }
  }
  return null;
}

/**
 * Check if token is expired (client-side only)
 */
export function isTokenExpired(token: string): boolean {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return true;

    const payload = JSON.parse(atob(parts[1]));
    const expiryTime = payload.exp * 1000; // convert to milliseconds

    return Date.now() >= expiryTime;
  } catch {
    return true;
  }
}

/**
 * Make authenticated request
 */
export async function authenticatedFetch(
  url: string,
  options: RequestInit = {}
): Promise<Response> {
  const token = getToken();

  if (!token || isTokenExpired(token)) {
    // Token expired or missing
    logout();
    throw new Error('Authentication required');
  }

  const headers = {
    ...options.headers,
    Authorization: `Bearer ${token}`,
  };

  const response = await fetch(url, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    // Unauthorized - token might have been revoked
    logout();
    throw new Error('Session expired');
  }

  return response;
}
