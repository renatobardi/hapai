import { DomainError } from '../../domain/errors/DomainError';
import { InvalidEmailError } from '../../domain/errors/InvalidEmailError';
import { InvalidPasswordError } from '../../domain/errors/InvalidPasswordError';
import { InvalidCredentialsError } from '../../domain/errors/InvalidCredentialsError';
import { UserNotFoundError } from '../../domain/errors/UserNotFoundError';
import { InvalidUserError } from '../../domain/errors/InvalidUserError';

/**
 * Maps domain errors to HTTP status codes and messages
 * Provides consistent error responses across the API
 */
export class ErrorMapper {
  /**
   * Map domain error to HTTP response
   */
  static toHttpResponse(error: unknown): {
    status: number;
    body: { error: string; code?: string };
  } {
    // Handle domain errors
    if (error instanceof InvalidEmailError) {
      return {
        status: 400,
        body: { error: 'Invalid email format', code: 'INVALID_EMAIL' }
      };
    }

    if (error instanceof InvalidPasswordError) {
      return {
        status: 400,
        body: { error: 'Password does not meet requirements', code: 'INVALID_PASSWORD' }
      };
    }

    if (error instanceof InvalidCredentialsError) {
      return {
        status: 401,
        body: { error: 'Invalid email or password', code: 'INVALID_CREDENTIALS' }
      };
    }

    if (error instanceof UserNotFoundError) {
      return {
        status: 404,
        body: { error: 'User not found', code: 'USER_NOT_FOUND' }
      };
    }

    if (error instanceof InvalidUserError) {
      return {
        status: 400,
        body: { error: (error as InvalidUserError).message, code: 'INVALID_USER' }
      };
    }

    if (error instanceof DomainError) {
      return {
        status: 400,
        body: { error: (error as DomainError).message, code: (error as DomainError).code }
      };
    }

    // Handle generic errors
    if (error instanceof Error) {
      console.error('Unexpected error:', error);
      return {
        status: 500,
        body: { error: 'Internal server error' }
      };
    }

    // Handle unknown errors
    console.error('Unknown error:', error);
    return {
      status: 500,
      body: { error: 'Internal server error' }
    };
  }
}
