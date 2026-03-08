import { describe, it, expect, beforeEach, vi } from 'vitest';
import { LoginUseCase } from '../../../../application/use-cases/login/LoginUseCase';
import { LoginRequest } from '../../../../application/dto/LoginRequest';
import { User } from '../../../../domain/entities/User';
import { Email } from '../../../../domain/value-objects/Email';
import { Password } from '../../../../domain/value-objects/Password';
import { InvalidCredentialsError } from '../../../../domain/errors/InvalidCredentialsError';
import type { IUserRepository } from '../../../../domain/repositories/IUserRepository';
import type { IPasswordHasher } from '../../../../application/ports/IPasswordHasher';
import type { ITokenGenerator } from '../../../../application/ports/ITokenGenerator';

describe('LoginUseCase', () => {
  let useCase: LoginUseCase;
  let userRepository: IUserRepository;
  let passwordHasher: IPasswordHasher;
  let tokenGenerator: ITokenGenerator;
  let testUser: User;
  const testPassword = 'SecurePass123!';
  const testEmail = 'test@example.com';

  beforeEach(async () => {
    // Mock repositories and adapters
    userRepository = {
      save: vi.fn(),
      findById: vi.fn(),
      findByEmail: vi.fn(),
      delete: vi.fn(),
      exists: vi.fn(),
      count: vi.fn()
    };

    passwordHasher = {
      hash: vi.fn(),
      compare: vi.fn()
    };

    tokenGenerator = {
      generate: vi.fn(),
      verify: vi.fn(),
      decode: vi.fn(),
      isExpired: vi.fn()
    };

    // Create test user
    const hashedPassword = await Password.create(testPassword);
    testUser = User.create({
      email: Email.fromString(testEmail),
      passwordHash: hashedPassword,
      name: 'Test User'
    });

    useCase = new LoginUseCase(userRepository, passwordHasher, tokenGenerator);
  });

  describe('execute', () => {
    it('should login successfully with valid credentials', async () => {
      const request = new LoginRequest(testEmail, testPassword);

      // Mock userRepository to return test user
      vi.mocked(userRepository.findByEmail).mockResolvedValue(testUser);

      // Mock passwordHasher to return true (password matches)
      vi.mocked(passwordHasher.compare).mockResolvedValue(true);

      // Mock tokenGenerator to return token
      const mockToken = 'mock-jwt-token';
      vi.mocked(tokenGenerator.generate).mockResolvedValue(mockToken);

      const response = await useCase.execute(request);

      expect(response.token).toBe(mockToken);
      expect(response.user.id).toBe(testUser.id.getValue());
      expect(response.user.email).toBe(testEmail);
      expect(response.user.name).toBe('Test User');
      expect(response.user.roles).toContain('USER');
    });

    it('should throw InvalidCredentialsError when user does not exist', async () => {
      const request = new LoginRequest('nonexistent@example.com', testPassword);

      vi.mocked(userRepository.findByEmail).mockResolvedValue(null);

      // Security: Should throw InvalidCredentialsError, not UserNotFoundError
      // This prevents user enumeration attacks
      await expect(useCase.execute(request)).rejects.toThrow(InvalidCredentialsError);
    });

    it('should throw InvalidCredentialsError when password is incorrect', async () => {
      const request = new LoginRequest(testEmail, 'WrongPassword123!');

      vi.mocked(userRepository.findByEmail).mockResolvedValue(testUser);
      vi.mocked(passwordHasher.compare).mockResolvedValue(false);

      await expect(useCase.execute(request)).rejects.toThrow(InvalidCredentialsError);
    });

    it('should update user lastLogin after successful authentication', async () => {
      const request = new LoginRequest(testEmail, testPassword);

      vi.mocked(userRepository.findByEmail).mockResolvedValue(testUser);
      vi.mocked(passwordHasher.compare).mockResolvedValue(true);
      vi.mocked(tokenGenerator.generate).mockResolvedValue('mock-token');

      await useCase.execute(request);

      // Verify lastLogin was updated (should not be null anymore)
      expect(testUser.lastLogin).not.toBeNull();
    });

    it('should save user after updating lastLogin', async () => {
      const request = new LoginRequest(testEmail, testPassword);

      vi.mocked(userRepository.findByEmail).mockResolvedValue(testUser);
      vi.mocked(passwordHasher.compare).mockResolvedValue(true);
      vi.mocked(tokenGenerator.generate).mockResolvedValue('mock-token');

      await useCase.execute(request);

      // Verify repository.save was called
      expect(userRepository.save).toHaveBeenCalledWith(testUser);
    });

    it('should call tokenGenerator with correct payload', async () => {
      const request = new LoginRequest(testEmail, testPassword);

      vi.mocked(userRepository.findByEmail).mockResolvedValue(testUser);
      vi.mocked(passwordHasher.compare).mockResolvedValue(true);
      vi.mocked(tokenGenerator.generate).mockResolvedValue('mock-token');

      await useCase.execute(request);

      expect(tokenGenerator.generate).toHaveBeenCalledWith({
        userId: testUser.id.getValue(),
        email: testUser.email.getValue(),
        roles: testUser.roles.map(r => r.getValue())
      });
    });

    it('should throw InvalidCredentialsError with generic message (no user enumeration)', async () => {
      const request = new LoginRequest('nonexistent@example.com', testPassword);

      vi.mocked(userRepository.findByEmail).mockResolvedValue(null);

      try {
        await useCase.execute(request);
        expect.fail('Should have thrown error');
      } catch (err) {
        if (err instanceof InvalidCredentialsError) {
          expect(err.message).not.toContain('not found');
          expect(err.message).not.toContain('nonexistent');
        } else {
          throw err;
        }
      }
    });
  });

  describe('constructor', () => {
    it('should create use case with dependencies', () => {
      const newUseCase = new LoginUseCase(userRepository, passwordHasher, tokenGenerator);
      expect(newUseCase).toBeDefined();
    });
  });
});
