import { describe, it, expect } from 'vitest';
import { Password } from '../../../../domain/value-objects/Password';
import { InvalidPasswordError } from '../../../../domain/errors/InvalidPasswordError';

describe('Password Value Object', () => {
  const validPassword = 'SecurePass123';
  const hashedPassword = '$2b$10$examplehash';

  describe('validateStrength', () => {
    it('should validate strong password', () => {
      expect(() => Password.validateStrength(validPassword)).not.toThrow();
    });

    it('should throw error for empty password', () => {
      expect(() => Password.validateStrength('')).toThrow(InvalidPasswordError);
    });

    it('should throw error for password less than 8 characters', () => {
      expect(() => Password.validateStrength('Pass12')).toThrow(InvalidPasswordError);
    });

    it('should throw error for password without uppercase', () => {
      expect(() => Password.validateStrength('securepass123')).toThrow(InvalidPasswordError);
    });

    it('should throw error for password without lowercase', () => {
      expect(() => Password.validateStrength('SECUREPASS123')).toThrow(InvalidPasswordError);
    });

    it('should throw error for password without number', () => {
      expect(() => Password.validateStrength('SecurePass')).toThrow(InvalidPasswordError);
    });

    it('should accept password with special characters', () => {
      expect(() => Password.validateStrength('SecurePass123!')).not.toThrow();
    });
  });

  describe('fromPlaintext', () => {
    it('should create Password from hash', () => {
      const password = Password.fromPlaintext(hashedPassword);
      expect(password.getHash()).toBe(hashedPassword);
    });

    it('should throw error for empty hash', () => {
      expect(() => Password.fromPlaintext('')).toThrow(InvalidPasswordError);
    });
  });

  describe('fromHash', () => {
    it('should create Password from existing hash', () => {
      const password = Password.fromHash(hashedPassword);
      expect(password.getHash()).toBe(hashedPassword);
    });
  });

  describe('getHash', () => {
    it('should return the hash', () => {
      const password = Password.fromHash(hashedPassword);
      expect(password.getHash()).toBe(hashedPassword);
    });
  });

  describe('toString', () => {
    it('should return hash in string representation', () => {
      const password = Password.fromHash(hashedPassword);
      expect(password.toString()).toBe(hashedPassword);
    });
  });
});
