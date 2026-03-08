import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ProfileHandler } from '../../../../presentation/handlers/ProfileHandler';
import { User } from '../../../../domain/entities/User';
import { Email } from '../../../../domain/value-objects/Email';
import { Password } from '../../../../domain/value-objects/Password';
import { UserNotFoundError } from '../../../../domain/errors/UserNotFoundError';
import { InvalidUserError } from '../../../../domain/errors/InvalidUserError';
import type { GetProfileUseCase } from '../../../../application/use-cases/get-profile/GetProfileUseCase';

describe('ProfileHandler', () => {
  let handler: ProfileHandler;
  let getProfileUseCase: GetProfileUseCase;
  let testUser: User;

  beforeEach(async () => {
    // Mock use case
    getProfileUseCase = {
      execute: vi.fn()
    } as any;

    handler = new ProfileHandler(getProfileUseCase);

    // Create test user
    const hashedPassword = await Password.create('SecurePass123!');
    testUser = User.create({
      email: Email.fromString('test@example.com'),
      passwordHash: hashedPassword,
      name: 'Test User'
    });
  });

  describe('handle', () => {
    it('should return 200 with user profile on success', async () => {
      const userId = testUser.id.getValue();

      vi.mocked(getProfileUseCase.execute).mockResolvedValue({
        user: {
          id: userId,
          email: 'test@example.com',
          name: 'Test User',
          roles: ['USER'],
          createdAt: new Date().toISOString(),
          lastLogin: null
        }
      });

      const result = await handler.handle(userId);

      expect(result.status).toBe(200);
      expect((result.body as any).id).toBe(userId);
      expect((result.body as any).email).toBe('test@example.com');
    });

    it('should return 400 when userId is empty', async () => {
      const result = await handler.handle('');

      expect(result.status).toBe(400);
      expect((result.body as any).error).toContain('required');
    });

    it('should return 404 when user not found', async () => {
      const userId = '550e8400-e29b-41d4-a716-446655440000';

      vi.mocked(getProfileUseCase.execute).mockRejectedValue(new UserNotFoundError('User not found'));

      const result = await handler.handle(userId);

      expect(result.status).toBe(404);
      expect((result.body as any).error).toContain('not found');
    });

    it('should return 400 on invalid userId format', async () => {
      const invalidUserId = 'invalid-id';

      vi.mocked(getProfileUseCase.execute).mockRejectedValue(
        new InvalidUserError('Invalid UserId format')
      );

      const result = await handler.handle(invalidUserId);

      expect(result.status).toBe(400);
    });

    it('should call use case with correct userId', async () => {
      const userId = testUser.id.getValue();

      vi.mocked(getProfileUseCase.execute).mockResolvedValue({
        user: {
          id: userId,
          email: 'test@example.com',
          name: 'Test User',
          roles: ['USER'],
          createdAt: new Date().toISOString(),
          lastLogin: null
        }
      });

      await handler.handle(userId);

      expect(getProfileUseCase.execute).toHaveBeenCalled();
    });

    it('should include all user details in response', async () => {
      const userId = testUser.id.getValue();
      const createdAt = new Date().toISOString();
      const lastLogin = new Date().toISOString();

      vi.mocked(getProfileUseCase.execute).mockResolvedValue({
        user: {
          id: userId,
          email: 'test@example.com',
          name: 'Test User',
          roles: ['USER', 'ADMIN'],
          createdAt,
          lastLogin
        }
      });

      const result = await handler.handle(userId);

      expect(result.status).toBe(200);
      expect((result.body as any).name).toBe('Test User');
      expect((result.body as any).roles).toContain('ADMIN');
      expect((result.body as any).createdAt).toBe(createdAt);
      expect((result.body as any).lastLogin).toBe(lastLogin);
    });
  });
});
