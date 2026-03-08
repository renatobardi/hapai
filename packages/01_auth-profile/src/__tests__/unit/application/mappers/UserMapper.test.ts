import { describe, it, expect, beforeEach } from 'vitest';
import { UserMapper } from '../../../../application/dto/mappers/UserMapper';
import { User } from '../../../../domain/entities/User';
import { Email } from '../../../../domain/value-objects/Email';
import { Password } from '../../../../domain/value-objects/Password';
import { Role } from '../../../../domain/value-objects/Role';

describe('UserMapper', () => {
  let testUser: User;

  beforeEach(async () => {
    const hashedPassword = await Password.create('SecurePass123!');
    testUser = User.create({
      email: Email.fromString('test@example.com'),
      passwordHash: hashedPassword,
      name: 'Test User'
    });
  });

  describe('toLoginResponse', () => {
    it('should map user entity to login response DTO', () => {
      const response = UserMapper.toLoginResponse(testUser);

      expect(response.id).toBe(testUser.id.getValue());
      expect(response.email).toBe('test@example.com');
      expect(response.name).toBe('Test User');
      expect(response.roles).toContain('USER');
    });

    it('should not include password hash in response', () => {
      const response = UserMapper.toLoginResponse(testUser);

      expect((response as any).passwordHash).toBeUndefined();
      expect((response as any).password).toBeUndefined();
    });

    it('should include all roles', () => {
      testUser.addRole(Role.ADMIN);

      const response = UserMapper.toLoginResponse(testUser);

      expect(response.roles.length).toBeGreaterThan(1);
      expect(response.roles).toContain('ADMIN');
    });
  });

  describe('toRegisterResponse', () => {
    it('should map user entity to register response DTO', () => {
      const response = UserMapper.toRegisterResponse(testUser);

      expect(response.id).toBe(testUser.id.getValue());
      expect(response.email).toBe('test@example.com');
      expect(response.name).toBe('Test User');
      expect(response.roles).toContain('USER');
    });

    it('should not include password hash in response', () => {
      const response = UserMapper.toRegisterResponse(testUser);

      expect((response as any).passwordHash).toBeUndefined();
      expect((response as any).password).toBeUndefined();
    });
  });

  describe('toProfileResponse', () => {
    it('should map user entity to profile response DTO', () => {
      const response = UserMapper.toProfileResponse(testUser);

      expect(response.id).toBe(testUser.id.getValue());
      expect(response.email).toBe('test@example.com');
      expect(response.name).toBe('Test User');
      expect(response.roles).toContain('USER');
    });

    it('should include ISO formatted timestamps', () => {
      const response = UserMapper.toProfileResponse(testUser);

      expect(response.createdAt).toBeDefined();
      expect(typeof response.createdAt).toBe('string');
      // Verify it's ISO format (contains T and Z)
      expect(response.createdAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    });

    it('should include lastLogin as null when not set', () => {
      const response = UserMapper.toProfileResponse(testUser);

      expect(response.lastLogin).toBeNull();
    });

    it('should include lastLogin as ISO string when set', () => {
      testUser.recordLogin();

      const response = UserMapper.toProfileResponse(testUser);

      expect(response.lastLogin).not.toBeNull();
      expect(typeof response.lastLogin).toBe('string');
      expect(response.lastLogin).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    });

    it('should not include password hash in profile response', () => {
      const response = UserMapper.toProfileResponse(testUser);

      expect((response as any).passwordHash).toBeUndefined();
      expect((response as any).password).toBeUndefined();
    });

    it('should preserve user roles in profile', () => {
      testUser.addRole(Role.ADMIN);

      const response = UserMapper.toProfileResponse(testUser);

      expect(response.roles.length).toBeGreaterThanOrEqual(1);
      expect(response.roles).toContain('ADMIN');
    });
  });
});
