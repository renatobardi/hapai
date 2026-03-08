import { describe, it, expect } from 'vitest';
import { UserId } from '../../../../domain/value-objects/UserId';
import { InvalidUserError } from '../../../../domain/errors/InvalidUserError';

describe('UserId Value Object', () => {
  it('should generate a new UserId', () => {
    const userId = UserId.generate();
    expect(userId.getValue()).toBeDefined();
    expect(userId.getValue()).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    );
  });

  it('should generate different IDs on each call', () => {
    const userId1 = UserId.generate();
    const userId2 = UserId.generate();
    expect(userId1.equals(userId2)).toBe(false);
  });

  it('should create from valid UUID string', () => {
    const uuidString = '550e8400-e29b-41d4-a716-446655440000';
    const userId = UserId.fromString(uuidString);
    expect(userId.getValue()).toBe(uuidString);
  });

  it('should throw error for invalid UUID format', () => {
    expect(() => UserId.fromString('invalid-uuid')).toThrow(InvalidUserError);
  });

  it('should throw error for empty string', () => {
    expect(() => UserId.fromString('')).toThrow(InvalidUserError);
  });

  it('should compare two UserIds', () => {
    const id = '550e8400-e29b-41d4-a716-446655440000';
    const userId1 = UserId.fromString(id);
    const userId2 = UserId.fromString(id);
    const userId3 = UserId.generate();

    expect(userId1.equals(userId2)).toBe(true);
    expect(userId1.equals(userId3)).toBe(false);
  });

  it('should return string representation', () => {
    const id = '550e8400-e29b-41d4-a716-446655440000';
    const userId = UserId.fromString(id);
    expect(userId.toString()).toBe(id);
  });
});
