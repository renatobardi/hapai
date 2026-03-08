import { describe, it, expect, beforeEach } from 'vitest';
import { User } from '../../../../domain/entities/User';
import { Email, UserId, Password, Role } from '../../../../domain/value-objects';
import { InvalidUserError } from '../../../../domain/errors/InvalidUserError';

describe('User Entity', () => {
  let validEmail: Email;
  let validPassword: Password;
  const validName = 'John Doe';
  const passwordHash = '$2b$10$examplehash';

  beforeEach(() => {
    validEmail = Email.fromString('user@example.com');
    validPassword = Password.fromHash(passwordHash);
  });

  describe('create', () => {
    it('should create a new user with valid data', () => {
      const user = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });

      expect(user.name).toBe(validName);
      expect(user.email.equals(validEmail)).toBe(true);
      expect(user.id).toBeDefined();
      expect(user.createdAt).toBeDefined();
      expect(user.lastLogin).toBeNull();
      expect(user.roles).toContain(Role.USER);
    });

    it('should throw error for empty name', () => {
      expect(() =>
        User.create({
          email: validEmail,
          passwordHash: validPassword,
          name: ''
        })
      ).toThrow(InvalidUserError);
    });

    it('should throw error for whitespace-only name', () => {
      expect(() =>
        User.create({
          email: validEmail,
          passwordHash: validPassword,
          name: '   '
        })
      ).toThrow(InvalidUserError);
    });

    it('should throw error for name longer than 255 characters', () => {
      const longName = 'a'.repeat(256);
      expect(() =>
        User.create({
          email: validEmail,
          passwordHash: validPassword,
          name: longName
        })
      ).toThrow(InvalidUserError);
    });

    it('should assign USER role by default', () => {
      const user = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });

      expect(user.hasRole(Role.USER)).toBe(true);
      expect(user.hasRole(Role.ADMIN)).toBe(false);
    });

    it('should generate unique IDs for different users', () => {
      const user1 = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });

      const user2 = User.create({
        email: Email.fromString('other@example.com'),
        passwordHash: validPassword,
        name: 'Jane Doe'
      });

      expect(user1.id.equals(user2.id)).toBe(false);
    });
  });

  describe('reconstruct', () => {
    it('should reconstruct user from database', () => {
      const userId = UserId.generate();
      const user = User.reconstruct({
        id: userId.getValue(),
        email: 'user@example.com',
        passwordHash: passwordHash,
        name: validName,
        roles: ['USER', 'ADMIN'],
        createdAt: new Date('2024-01-01'),
        lastLogin: new Date('2024-01-15')
      });

      expect(user.id.equals(userId)).toBe(true);
      expect(user.email.getValue()).toBe('user@example.com');
      expect(user.name).toBe(validName);
      expect(user.hasRole(Role.USER)).toBe(true);
      expect(user.hasRole(Role.ADMIN)).toBe(true);
    });
  });

  describe('verifyPasswordHash', () => {
    it('should verify password hash', () => {
      const user = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });

      expect(user.verifyPasswordHash(passwordHash)).toBe(true);
    });

    it('should return false for incorrect hash', () => {
      const user = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });

      expect(user.verifyPasswordHash('wronghash')).toBe(false);
    });
  });

  describe('recordLogin', () => {
    it('should update lastLogin timestamp', () => {
      const user = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });

      expect(user.lastLogin).toBeNull();

      user.recordLogin();

      expect(user.lastLogin).toBeDefined();
      expect(user.lastLogin).toBeInstanceOf(Date);
    });

    it('should update lastLogin on subsequent calls', () => {
      const user = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });

      user.recordLogin();
      const firstLogin = user.lastLogin;

      // Small delay to ensure different timestamp
      user.recordLogin();
      const secondLogin = user.lastLogin;

      expect(secondLogin?.getTime()).toBeGreaterThanOrEqual(firstLogin?.getTime() || 0);
    });
  });

  describe('role management', () => {
    let user: User;

    beforeEach(() => {
      user = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });
    });

    it('should add role to user', () => {
      user.addRole(Role.ADMIN);
      expect(user.hasRole(Role.ADMIN)).toBe(true);
    });

    it('should throw error when adding duplicate role', () => {
      user.addRole(Role.ADMIN);
      expect(() => user.addRole(Role.ADMIN)).toThrow(InvalidUserError);
    });

    it('should remove role from user', () => {
      user.addRole(Role.ADMIN);
      expect(user.hasRole(Role.ADMIN)).toBe(true);

      user.removeRole(Role.ADMIN);
      expect(user.hasRole(Role.ADMIN)).toBe(false);
    });

    it('should throw error when removing non-existent role', () => {
      expect(() => user.removeRole(Role.ADMIN)).toThrow(InvalidUserError);
    });

    it('should check if user is admin', () => {
      expect(user.isAdmin()).toBe(false);
      user.addRole(Role.ADMIN);
      expect(user.isAdmin()).toBe(true);
    });
  });

  describe('toPlainObject', () => {
    it('should convert user to plain object', () => {
      const user = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });

      const plain = user.toPlainObject();

      expect(plain.id).toBeDefined();
      expect(plain.email).toBe('user@example.com');
      expect(plain.name).toBe(validName);
      expect(plain.roles).toContain('USER');
      expect(plain.createdAt).toBeDefined();
      expect(plain.lastLogin).toBeNull();
    });
  });

  describe('getPasswordHash', () => {
    it('should return password hash', () => {
      const user = User.create({
        email: validEmail,
        passwordHash: validPassword,
        name: validName
      });

      expect(user.getPasswordHash()).toBe(passwordHash);
    });
  });
});
