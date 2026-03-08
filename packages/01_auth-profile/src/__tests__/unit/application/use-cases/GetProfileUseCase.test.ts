import { describe, it, expect, beforeEach, vi } from 'vitest';
import { GetProfileUseCase } from '../../../../application/use-cases/get-profile/GetProfileUseCase';
import { GetProfileRequest } from '../../../../application/dto/GetProfileRequest';
import { User } from '../../../../domain/entities/User';
import { Email } from '../../../../domain/value-objects/Email';
import { Password } from '../../../../domain/value-objects/Password';
import { Role } from '../../../../domain/value-objects/Role';
import { UserNotFoundError } from '../../../../domain/errors/UserNotFoundError';
import type { IUserRepository } from '../../../../domain/repositories/IUserRepository';

describe('GetProfileUseCase', () => {
  let useCase: GetProfileUseCase;
  let userRepository: IUserRepository;
  let testUser: User;

  beforeEach(async () => {
    // Mock repository
    userRepository = {
      save: vi.fn(),
      findById: vi.fn(),
      findByEmail: vi.fn(),
      delete: vi.fn(),
      exists: vi.fn(),
      count: vi.fn()
    };

    // Create test user
    const hashedPassword = await Password.create('SecurePass123!');
    testUser = User.create({
      email: Email.fromString('test@example.com'),
      passwordHash: hashedPassword,
      name: 'Test User'
    });

    useCase = new GetProfileUseCase(userRepository);
  });

  describe('execute', () => {
    it('should return user profile when user exists', async () => {
      const request = new GetProfileRequest(testUser.id.getValue());

      vi.mocked(userRepository.findById).mockResolvedValue(testUser);

      const response = await useCase.execute(request);

      expect(response.user.id).toBe(testUser.id.getValue());
      expect(response.user.email).toBe('test@example.com');
      expect(response.user.name).toBe('Test User');
      expect(response.user.roles).toContain('USER');
    });

    it('should include timestamps in response', async () => {
      const request = new GetProfileRequest(testUser.id.getValue());

      vi.mocked(userRepository.findById).mockResolvedValue(testUser);

      const response = await useCase.execute(request);

      expect(response.user.createdAt).toBeDefined();
      expect(typeof response.user.createdAt).toBe('string');
    });

    it('should include lastLogin timestamp when available', async () => {
      // Update lastLogin
      testUser.recordLogin();

      const request = new GetProfileRequest(testUser.id.getValue());
      vi.mocked(userRepository.findById).mockResolvedValue(testUser);

      const response = await useCase.execute(request);

      expect(response.user.lastLogin).not.toBeNull();
      expect(typeof response.user.lastLogin).toBe('string');
    });

    it('should return null for lastLogin when not yet logged in', async () => {
      // User hasn't logged in yet, lastLogin is null
      const request = new GetProfileRequest(testUser.id.getValue());
      vi.mocked(userRepository.findById).mockResolvedValue(testUser);

      const response = await useCase.execute(request);

      expect(response.user.lastLogin).toBeNull();
    });

    it('should throw UserNotFoundError when user does not exist', async () => {
      const nonExistentUserId = '550e8400-e29b-41d4-a716-446655440000';
      const request = new GetProfileRequest(nonExistentUserId);

      vi.mocked(userRepository.findById).mockResolvedValue(null);

      await expect(useCase.execute(request)).rejects.toThrow(UserNotFoundError);
    });

    it('should call repository with correct userId', async () => {
      const userId = testUser.id.getValue();
      const request = new GetProfileRequest(userId);

      vi.mocked(userRepository.findById).mockResolvedValue(testUser);

      await useCase.execute(request);

      expect(userRepository.findById).toHaveBeenCalled();
    });

    it('should include all user roles', async () => {
      // Add an admin role
      testUser.addRole(Role.ADMIN);

      const request = new GetProfileRequest(testUser.id.getValue());
      vi.mocked(userRepository.findById).mockResolvedValue(testUser);

      const response = await useCase.execute(request);

      expect(response.user.roles.length).toBeGreaterThan(0);
      expect(response.user.roles).toContain('ADMIN');
    });
  });

  describe('constructor', () => {
    it('should create use case with repository', () => {
      const newUseCase = new GetProfileUseCase(userRepository);
      expect(newUseCase).toBeDefined();
    });
  });
});
