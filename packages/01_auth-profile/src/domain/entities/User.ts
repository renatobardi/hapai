import { UserId, Email, Password, Role } from '../value-objects';
import { InvalidUserError } from '../errors/InvalidUserError';

/**
 * User Entity
 * - Core domain entity with business logic
 * - Aggregate root for user domain
 * - Immutable identity (id, email, createdAt)
 * - Mutable attributes (name, lastLogin)
 */
export class User {
  private constructor(
    public readonly id: UserId,
    public readonly email: Email,
    private passwordHash: Password,
    public name: string,
    public readonly roles: Role[],
    public readonly createdAt: Date,
    public lastLogin: Date | null
  ) {}

  /**
   * Create a new User (factory method)
   * Called when registering a new user
   */
  static create(props: {
    email: Email;
    passwordHash: Password;
    name: string;
  }): User {
    User.validateProps(props);

    return new User(
      UserId.generate(),
      props.email,
      props.passwordHash,
      props.name,
      [Role.USER], // Default role
      new Date(),
      null
    );
  }

  /**
   * Reconstruct User from database
   * Called when loading from persistence
   */
  static reconstruct(props: {
    id: string;
    email: string;
    passwordHash: string;
    name: string;
    roles: string[];
    createdAt: Date;
    lastLogin: Date | null;
  }): User {
    return new User(
      UserId.fromString(props.id),
      Email.fromString(props.email),
      Password.fromHash(props.passwordHash),
      props.name,
      props.roles.map(r => Role.fromString(r)),
      props.createdAt,
      props.lastLogin
    );
  }

  /**
   * Validate user properties
   */
  private static validateProps(props: {
    email: Email;
    passwordHash: Password;
    name: string;
  }): void {
    if (!props.name || props.name.trim().length === 0) {
      throw new InvalidUserError('Name cannot be empty');
    }

    if (props.name.length > 255) {
      throw new InvalidUserError('Name must be less than 255 characters');
    }
  }

  /**
   * Verify password against stored hash
   * This is a behavior - the domain knows how to verify
   * Implementation details (bcrypt) are hidden
   */
  verifyPasswordHash(hash: string): boolean {
    return this.passwordHash.getHash() === hash;
  }

  /**
   * Update last login timestamp
   */
  recordLogin(): void {
    this.lastLogin = new Date();
  }

  /**
   * Check if user has a specific role
   */
  hasRole(role: Role): boolean {
    return this.roles.some(r => r.equals(role));
  }

  /**
   * Check if user is admin
   */
  isAdmin(): boolean {
    return this.hasRole(Role.ADMIN);
  }

  /**
   * Add role to user
   */
  addRole(role: Role): void {
    if (this.hasRole(role)) {
      throw new InvalidUserError(`User already has role ${role.getValue()}`);
    }
    this.roles.push(role);
  }

  /**
   * Remove role from user
   */
  removeRole(role: Role): void {
    if (!this.hasRole(role)) {
      throw new InvalidUserError(`User does not have role ${role.getValue()}`);
    }
    const index = this.roles.findIndex(r => r.equals(role));
    if (index >= 0) {
      this.roles.splice(index, 1);
    }
  }

  /**
   * Get password hash (for persistence)
   */
  getPasswordHash(): string {
    return this.passwordHash.getHash();
  }

  /**
   * Convert to plain object (for DTOs)
   */
  toPlainObject(): {
    id: string;
    email: string;
    name: string;
    roles: string[];
    createdAt: Date;
    lastLogin: Date | null;
  } {
    return {
      id: this.id.getValue(),
      email: this.email.getValue(),
      name: this.name,
      roles: this.roles.map(r => r.getValue()),
      createdAt: this.createdAt,
      lastLogin: this.lastLogin
    };
  }
}
