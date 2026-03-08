import { describe, it, expect, beforeEach } from 'vitest';
import { PostgresUserRepository } from '../../../infrastructure/adapters/repositories/PostgresUserRepository';
import { User, Email, Password, UserId } from '../../../domain';

describe('PostgresUserRepository (Integration)', () => {
  let repository: PostgresUserRepository;
  let testUser: User;
  let testEmail: Email;
  const passwordHash = '$2b$10$examplehash';

  beforeEach(async () => {
    repository = new PostgresUserRepository();
    testEmail = Email.fromString('test@example.com');
    const passwordObj = Password.fromHash(passwordHash);

    testUser = User.create({
      email: testEmail,
      passwordHash: passwordObj,
      name: 'Test User'
    });
  });

  describe('save', () => {
    it('should save user to repository', async () => {
      await repository.save(testUser);

      const found = await repository.findById(testUser.id);
      expect(found).toBeDefined();
      expect(found?.email.equals(testEmail)).toBe(true);
    });

    it('should update existing user', async () => {
      await repository.save(testUser);

      // Create a reference to the same user (same ID)
      const updatedUser = User.reconstruct({
        id: testUser.id.getValue(),
        email: testUser.email.getValue(),
        passwordHash: passwordHash,
        name: 'Updated Name',
        roles: testUser.roles.map(r => r.getValue()),
        createdAt: testUser['createdAt'],
        lastLogin: new Date()
      });

      await repository.save(updatedUser);

      const found = await repository.findById(testUser.id);
      expect(found?.name).toBe('Updated Name');
      expect(found?.lastLogin).not.toBeNull();
    });
  });

  describe('findById', () => {
    it('should find user by ID', async () => {
      await repository.save(testUser);

      const found = await repository.findById(testUser.id);
      expect(found).toBeDefined();
      expect(found?.id.equals(testUser.id)).toBe(true);
    });

    it('should return null for non-existent user', async () => {
      const nonExistentId = UserId.generate();
      const found = await repository.findById(nonExistentId);
      expect(found).toBeNull();
    });
  });

  describe('findByEmail', () => {
    it('should find user by email', async () => {
      await repository.save(testUser);

      const found = await repository.findByEmail(testEmail);
      expect(found).toBeDefined();
      expect(found?.email.equals(testEmail)).toBe(true);
    });

    it('should return null for non-existent email', async () => {
      const nonExistentEmail = Email.fromString('nonexistent@example.com');
      const found = await repository.findByEmail(nonExistentEmail);
      expect(found).toBeNull();
    });

    it('should be case-insensitive', async () => {
      await repository.save(testUser);

      const uppercaseEmail = Email.fromString('TEST@EXAMPLE.COM');
      const found = await repository.findByEmail(uppercaseEmail);
      expect(found).toBeDefined();
      expect(found?.email.getValue()).toBe('test@example.com');
    });
  });

  describe('delete', () => {
    it('should delete user from repository', async () => {
      await repository.save(testUser);
      await repository.delete(testUser.id);

      const found = await repository.findById(testUser.id);
      expect(found).toBeNull();
    });

    it('should not throw error when deleting non-existent user', async () => {
      const nonExistentId = UserId.generate();
      await expect(repository.delete(nonExistentId)).resolves.not.toThrow();
    });
  });

  describe('exists', () => {
    it('should return true for existing user', async () => {
      await repository.save(testUser);

      const exists = await repository.exists(testUser.id);
      expect(exists).toBe(true);
    });

    it('should return false for non-existent user', async () => {
      const nonExistentId = UserId.generate();
      const exists = await repository.exists(nonExistentId);
      expect(exists).toBe(false);
    });
  });

  describe('count', () => {
    it('should return 0 for empty repository', async () => {
      const count = await repository.count();
      expect(count).toBe(0);
    });

    it('should return correct count of users', async () => {
      const user1 = testUser;
      const user2 = User.create({
        email: Email.fromString('other@example.com'),
        passwordHash: Password.fromHash(passwordHash),
        name: 'Other User'
      });

      await repository.save(user1);
      await repository.save(user2);

      const count = await repository.count();
      expect(count).toBe(2);
    });
  });
});
