import { describe, it, expect, beforeEach, vi } from 'vitest';
import { RegisterUseCase } from '../../../../application/use-cases/register/RegisterUseCase';
import { RegisterRequest } from '../../../../application/dto/RegisterRequest';
import { Email } from '../../../../domain/value-objects/Email';
import { InvalidEmailError } from '../../../../domain/errors/InvalidEmailError';
import type { IUserRepository } from '../../../../domain/repositories/IUserRepository';
import type { IPasswordHasher } from '../../../../application/ports/IPasswordHasher';
import type { ITokenGenerator } from '../../../../application/ports/ITokenGenerator';

describe('RegisterUseCase', () => {
  let useCase: RegisterUseCase;
  let userRepository: IUserRepository;
  let passwordHasher: IPasswordHasher;
  let tokenGenerator: ITokenGenerator;

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

    useCase = new RegisterUseCase(userRepository, passwordHasher, tokenGenerator);
  });

  describe('execute', () => {
    it('should register user successfully with valid data', async () => {
      const request = new RegisterRequest('newuser@example.com', 'SecurePass123!', 'New User');

      // Mock that user doesn't exist
      vi.mocked(userRepository.findByEmail).mockResolvedValue(null);

      // Mock password hashing
      vi.mocked(passwordHasher.hash).mockResolvedValue({
        getHash: () => 'hashed-password',
        verify: vi.fn()
      } as any);

      // Mock token generation
      const mockToken = 'mock-jwt-token';
      vi.mocked(tokenGenerator.generate).mockResolvedValue(mockToken);

      const response = await useCase.execute(request);

      expect(response.token).toBe(mockToken);
      expect(response.user.email).toBe('newuser@example.com');
      expect(response.user.name).toBe('New User');
      expect(response.user.roles).toContain('USER');
    });

    it('should throw error if user already exists', async () => {
      const request = new RegisterRequest('existing@example.com', 'SecurePass123!', 'Existing User');

      // Mock that user already exists
      vi.mocked(userRepository.findByEmail).mockResolvedValue({
        id: { getValue: () => 'user-id' },
        email: Email.fromString('existing@example.com'),
        name: 'Existing User',
        roles: [],
        createdAt: new Date(),
        lastLogin: null,
        getPasswordHash: () => 'hash',
        recordLogin: () => {},
        hasRole: () => false,
        isAdmin: () => false,
        addRole: () => {},
        removeRole: () => {},
        verifyPasswordHash: () => Promise.resolve(false),
        toPlainObject: () => ({})
      } as any);

      await expect(useCase.execute(request)).rejects.toThrow('User already registered');
    });

    it('should throw error on invalid email', async () => {
      const request = new RegisterRequest('invalid-email', 'SecurePass123!', 'New User');

      await expect(useCase.execute(request)).rejects.toThrow(InvalidEmailError);
    });

    it('should save user after registration', async () => {
      const request = new RegisterRequest('newuser@example.com', 'SecurePass123!', 'New User');

      vi.mocked(userRepository.findByEmail).mockResolvedValue(null);
      vi.mocked(passwordHasher.hash).mockResolvedValue({
        getHash: () => 'hashed-password',
        verify: vi.fn()
      } as any);
      vi.mocked(tokenGenerator.generate).mockResolvedValue('mock-token');

      await useCase.execute(request);

      // Verify repository.save was called
      expect(userRepository.save).toHaveBeenCalled();
    });

    it('should hash password before saving', async () => {
      const request = new RegisterRequest('newuser@example.com', 'SecurePass123!', 'New User');

      vi.mocked(userRepository.findByEmail).mockResolvedValue(null);
      vi.mocked(passwordHasher.hash).mockResolvedValue({
        getHash: () => 'hashed-password',
        verify: vi.fn()
      } as any);
      vi.mocked(tokenGenerator.generate).mockResolvedValue('mock-token');

      await useCase.execute(request);

      // Verify passwordHasher.hash was called with plaintext password
      expect(passwordHasher.hash).toHaveBeenCalledWith('SecurePass123!');
    });

    it('should generate token with correct user data', async () => {
      const request = new RegisterRequest('newuser@example.com', 'SecurePass123!', 'New User');

      vi.mocked(userRepository.findByEmail).mockResolvedValue(null);
      vi.mocked(passwordHasher.hash).mockResolvedValue({
        getHash: () => 'hashed-password',
        verify: vi.fn()
      } as any);
      vi.mocked(tokenGenerator.generate).mockResolvedValue('mock-token');

      await useCase.execute(request);

      // Verify tokenGenerator.generate was called
      expect(tokenGenerator.generate).toHaveBeenCalled();
      const callArgs = vi.mocked(tokenGenerator.generate).mock.calls[0][0];
      expect(callArgs.email).toBe('newuser@example.com');
      expect(callArgs.roles).toContain('USER');
    });

    it('should create user with name provided', async () => {
      const request = new RegisterRequest('newuser@example.com', 'SecurePass123!', 'John Doe');

      vi.mocked(userRepository.findByEmail).mockResolvedValue(null);
      vi.mocked(passwordHasher.hash).mockResolvedValue({
        getHash: () => 'hashed-password',
        verify: vi.fn()
      } as any);
      vi.mocked(tokenGenerator.generate).mockResolvedValue('mock-token');

      const response = await useCase.execute(request);

      expect(response.user.name).toBe('John Doe');
    });
  });
});
