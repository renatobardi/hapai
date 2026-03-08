import { describe, it, expect } from 'vitest';
import { Role } from '../../../../domain/value-objects/Role';
import { InvalidUserError } from '../../../../domain/errors/InvalidUserError';

describe('Role Value Object', () => {
  it('should create ADMIN role', () => {
    const role = Role.ADMIN;
    expect(role.getValue()).toBe('ADMIN');
  });

  it('should create USER role', () => {
    const role = Role.USER;
    expect(role.getValue()).toBe('USER');
  });

  it('should create role from string (uppercase)', () => {
    const adminRole = Role.fromString('ADMIN');
    const userRole = Role.fromString('USER');

    expect(adminRole.equals(Role.ADMIN)).toBe(true);
    expect(userRole.equals(Role.USER)).toBe(true);
  });

  it('should create role from string (lowercase)', () => {
    const adminRole = Role.fromString('admin');
    const userRole = Role.fromString('user');

    expect(adminRole.equals(Role.ADMIN)).toBe(true);
    expect(userRole.equals(Role.USER)).toBe(true);
  });

  it('should throw error for invalid role', () => {
    expect(() => Role.fromString('INVALID')).toThrow(InvalidUserError);
  });

  it('should return all available roles', () => {
    const roles = Role.all();
    expect(roles).toContain(Role.ADMIN);
    expect(roles).toContain(Role.USER);
    expect(roles.length).toBe(2);
  });

  it('should compare roles', () => {
    const admin1 = Role.ADMIN;
    const admin2 = Role.fromString('admin');
    const user = Role.USER;

    expect(admin1.equals(admin2)).toBe(true);
    expect(admin1.equals(user)).toBe(false);
  });

  it('should check if role is admin', () => {
    expect(Role.ADMIN.isAdmin()).toBe(true);
    expect(Role.USER.isAdmin()).toBe(false);
  });

  it('should return string representation', () => {
    expect(Role.ADMIN.toString()).toBe('ADMIN');
    expect(Role.USER.toString()).toBe('USER');
  });
});
