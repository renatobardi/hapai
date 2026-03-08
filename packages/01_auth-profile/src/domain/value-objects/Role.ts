import { InvalidUserError } from '../errors/InvalidUserError';

/**
 * Role Value Object
 * - Immutable enum-like value object
 * - Represents user roles
 */
export class Role {
  public static readonly ADMIN = new Role('ADMIN');
  public static readonly USER = new Role('USER');

  private constructor(private readonly value: string) {}

  /**
   * Create Role from string
   */
  static fromString(role: string): Role {
    const roleValue = role.toUpperCase();
    if (roleValue === 'ADMIN') return Role.ADMIN;
    if (roleValue === 'USER') return Role.USER;
    throw new InvalidUserError(`Invalid role: ${role}`);
  }

  /**
   * Get all available roles
   */
  static all(): Role[] {
    return [Role.ADMIN, Role.USER];
  }

  /**
   * Get the role value
   */
  getValue(): string {
    return this.value;
  }

  /**
   * Compare with another Role
   */
  equals(other: Role): boolean {
    return this.value === other.value;
  }

  /**
   * Check if this is admin role
   */
  isAdmin(): boolean {
    return this.equals(Role.ADMIN);
  }

  /**
   * String representation
   */
  toString(): string {
    return this.value;
  }
}
