import { describe, it, expect, beforeEach, vi } from 'vitest';
import { LoginHandler } from '../../../../presentation/handlers/LoginHandler';
import { User } from '../../../../domain/entities/User';
import { Email } from '../../../../domain/value-objects/Email';
import { Password } from '../../../../domain/value-objects/Password';
import { InvalidCredentialsError } from '../../../../domain/errors/InvalidCredentialsError';
import { InvalidEmailError } from '../../../../domain/errors/InvalidEmailError';
import type { LoginUseCase } from '../../../../application/use-cases/login/LoginUseCase';

describe('LoginHandler', () => {
  let handler: LoginHandler;
  let loginUseCase: LoginUseCase;
  let testUser: User;

  beforeEach(async () => {
    // Mock use case
    loginUseCase = {
      execute: vi.fn()
    } as any;

    handler = new LoginHandler(loginUseCase);

    // Create test user
    const hashedPassword = await Password.create('SecurePass123!');
    testUser = User.create({
      email: Email.fromString('test@example.com'),
      passwordHash: hashedPassword,
      name: 'Test User'
    });
  });

  describe('handle', () => {
    it('should return 200 with token on successful login', async () => {
      const body = { email: 'test@example.com', password: 'SecurePass123!' };

      vi.mocked(loginUseCase.execute).mockResolvedValue({
        token: 'mock-jwt-token',
        user: {
          id: testUser.id.getValue(),
          email: 'test@example.com',
          name: 'Test User',
          roles: ['USER']
        }
      });

      const result = await handler.handle(body);

      expect(result.status).toBe(200);
      expect((result.body as any).token).toBe('mock-jwt-token');
      expect((result.body as any).user.email).toBe('test@example.com');
    });

    it('should return 400 when email is missing', async () => {
      const body = { password: 'SecurePass123!' };

      const result = await handler.handle(body);

      expect(result.status).toBe(400);
      expect((result.body as any).error).toContain('Email and password');
    });

    it('should return 400 when password is missing', async () => {
      const body = { email: 'test@example.com' };

      const result = await handler.handle(body);

      expect(result.status).toBe(400);
      expect((result.body as any).error).toContain('Email and password');
    });

    it('should return 401 on invalid credentials', async () => {
      const body = { email: 'test@example.com', password: 'WrongPassword!' };

      vi.mocked(loginUseCase.execute).mockRejectedValue(
        new InvalidCredentialsError('Invalid email or password')
      );

      const result = await handler.handle(body);

      expect(result.status).toBe(401);
      expect((result.body as any).error).toContain('Invalid email or password');
    });

    it('should return 400 on invalid email format', async () => {
      const body = { email: 'invalid-email', password: 'SecurePass123!' };

      vi.mocked(loginUseCase.execute).mockRejectedValue(
        new InvalidEmailError('Invalid email format')
      );

      const result = await handler.handle(body);

      expect(result.status).toBe(400);
      expect((result.body as any).error).toContain('Invalid email');
    });

    it('should call use case with correct request', async () => {
      const body = { email: 'test@example.com', password: 'SecurePass123!' };

      vi.mocked(loginUseCase.execute).mockResolvedValue({
        token: 'mock-token',
        user: {
          id: 'user-id',
          email: 'test@example.com',
          name: 'Test User',
          roles: ['USER']
        }
      });

      await handler.handle(body);

      expect(loginUseCase.execute).toHaveBeenCalled();
    });
  });
});
