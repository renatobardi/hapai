import { describe, it, expect } from 'vitest';
import { Email } from '../../../../domain/value-objects/Email';
import { InvalidEmailError } from '../../../../domain/errors/InvalidEmailError';

describe('Email Value Object', () => {
  it('should create email with valid format', () => {
    const email = Email.fromString('user@example.com');
    expect(email.getValue()).toBe('user@example.com');
  });

  it('should convert email to lowercase', () => {
    const email = Email.fromString('USER@EXAMPLE.COM');
    expect(email.getValue()).toBe('user@example.com');
  });

  it('should throw error for empty email', () => {
    expect(() => Email.fromString('')).toThrow(InvalidEmailError);
  });

  it('should throw error for invalid format', () => {
    expect(() => Email.fromString('invalid-email')).toThrow(InvalidEmailError);
  });

  it('should throw error for email without @', () => {
    expect(() => Email.fromString('userexample.com')).toThrow(InvalidEmailError);
  });

  it('should throw error for email without domain', () => {
    expect(() => Email.fromString('user@')).toThrow(InvalidEmailError);
  });

  it('should throw error for email without TLD', () => {
    expect(() => Email.fromString('user@example')).toThrow(InvalidEmailError);
  });

  it('should compare two emails', () => {
    const email1 = Email.fromString('user@example.com');
    const email2 = Email.fromString('user@example.com');
    const email3 = Email.fromString('other@example.com');

    expect(email1.equals(email2)).toBe(true);
    expect(email1.equals(email3)).toBe(false);
  });

  it('should be case-insensitive when comparing', () => {
    const email1 = Email.fromString('USER@EXAMPLE.COM');
    const email2 = Email.fromString('user@example.com');

    expect(email1.equals(email2)).toBe(true);
  });

  it('should return string representation', () => {
    const email = Email.fromString('user@example.com');
    expect(email.toString()).toBe('user@example.com');
  });
});
