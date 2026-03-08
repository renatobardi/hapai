/**
 * Shared types for OUTE
 * Used across all packages
 */

export interface User {
  id: string;
  email: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface Project {
  id: string;
  userId: string;
  name: string;
  description: string;
  status: 'active' | 'archived';
  createdAt: Date;
  updatedAt: Date;
}

export interface JWTPayload {
  sub: string; // user_id
  email: string;
  iat: number;
  exp: number;
}

export interface AuthResponse {
  token: string;
  user: User;
}

export interface ApiError {
  status: number;
  message: string;
  code: string;
}

export interface ApiResponse<T> {
  data?: T;
  error?: ApiError;
  status: 'success' | 'error';
}
