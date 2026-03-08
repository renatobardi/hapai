import { describe, it, expect } from 'vitest';
import { ErrorMapper } from '../../../../presentation/errors/ErrorMapper';
import { InvalidEmailError } from '../../../../domain/errors/InvalidEmailError';
import { InvalidPasswordError } from '../../../../domain/errors/InvalidPasswordError';
import { InvalidCredentialsError } from '../../../../domain/errors/InvalidCredentialsError';
import { UserNotFoundError } from '../../../../domain/errors/UserNotFoundError';
import { InvalidUserError } from '../../../../domain/errors/InvalidUserError';

describe('ErrorMapper', () => {
  describe('toHttpResponse', () => {
    it('should map InvalidEmailError to 400', () => {
      const error = new InvalidEmailError('Invalid email format');
      const response = ErrorMapper.toHttpResponse(error);

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Invalid email');
      expect(response.body.code).toBe('INVALID_EMAIL');
    });

    it('should map InvalidPasswordError to 400', () => {
      const error = new InvalidPasswordError('Password too weak');
      const response = ErrorMapper.toHttpResponse(error);

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Password');
      expect(response.body.code).toBe('INVALID_PASSWORD');
    });

    it('should map InvalidCredentialsError to 401', () => {
      const error = new InvalidCredentialsError('Invalid email or password');
      const response = ErrorMapper.toHttpResponse(error);

      expect(response.status).toBe(401);
      expect(response.body.error).toContain('Invalid email or password');
      expect(response.body.code).toBe('INVALID_CREDENTIALS');
    });

    it('should map UserNotFoundError to 404', () => {
      const error = new UserNotFoundError('User not found');
      const response = ErrorMapper.toHttpResponse(error);

      expect(response.status).toBe(404);
      expect(response.body.error).toContain('User not found');
      expect(response.body.code).toBe('USER_NOT_FOUND');
    });

    it('should map InvalidUserError to 400', () => {
      const error = new InvalidUserError('Invalid user data');
      const response = ErrorMapper.toHttpResponse(error);

      expect(response.status).toBe(400);
      expect(response.body.error).toBeDefined();
      expect(response.body.code).toBe('INVALID_USER');
    });

    it('should map generic Error to 500', () => {
      const error = new Error('Something went wrong');
      const response = ErrorMapper.toHttpResponse(error);

      expect(response.status).toBe(500);
      expect(response.body.error).toBeDefined();
    });

    it('should map unknown error to 500', () => {
      const response = ErrorMapper.toHttpResponse('Unknown error');

      expect(response.status).toBe(500);
      expect(response.body.error).toBe('Internal server error');
    });

    it('should include error code in response', () => {
      const error = new InvalidCredentialsError('Bad credentials');
      const response = ErrorMapper.toHttpResponse(error);

      expect(response.body.code).toBeDefined();
      expect(typeof response.body.code).toBe('string');
    });

    it('should preserve error message for domain errors', () => {
      const message = 'Custom error message';
      const error = new InvalidUserError(message);
      const response = ErrorMapper.toHttpResponse(error);

      expect(response.body.error).toContain(message);
    });
  });
});
