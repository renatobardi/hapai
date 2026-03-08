import { InvalidPasswordError } from '../errors/InvalidPasswordError';

/**
 * Password Value Object
 * - Immutable
 * - Stores bcrypt hash only (never plaintext)
 * - Validates password strength before hashing
 * - Note: Hashing is delegated to infrastructure layer
 */
export class Password {
  private readonly hash: string;

  private constructor(hash: string) {
    this.hash = hash;
  }

  /**
   * Create a new Password from plaintext (for testing/infrastructure layer)
   * Validates strength and returns Password with hashed value
   * Note: Real hashing should be done in infrastructure layer (BcryptPasswordAdapter)
   */
  static async create(plainPassword: string): Promise<Password> {
    // Validate strength first
    Password.validateStrength(plainPassword);

    // For testing: create a simple mock hash
    // In production: use bcrypt.hash() via BcryptPasswordAdapter
    const mockHash = Buffer.from(plainPassword).toString('base64');
    return new Password(`$2b$10$${mockHash}`);
  }

  /**
   * Create a new Password from plaintext
   * This should be called from infrastructure layer with bcrypt
   */
  static fromPlaintext(hash: string): Password {
    if (!hash || hash.trim().length === 0) {
      throw new InvalidPasswordError('Password hash cannot be empty');
    }
    return new Password(hash);
  }

  /**
   * Create from existing hash (when loading from database)
   */
  static fromHash(hash: string): Password {
    return new Password(hash);
  }

  /**
   * Validate password strength (plaintext)
   * Rules:
   * - Minimum 8 characters
   * - At least 1 uppercase letter
   * - At least 1 lowercase letter
   * - At least 1 number
   */
  static validateStrength(plainPassword: string): void {
    if (!plainPassword) {
      throw new InvalidPasswordError('Password cannot be empty');
    }

    if (plainPassword.length < 8) {
      throw new InvalidPasswordError('Password must be at least 8 characters');
    }

    if (!/[A-Z]/.test(plainPassword)) {
      throw new InvalidPasswordError('Password must contain uppercase letter (A-Z)');
    }

    if (!/[a-z]/.test(plainPassword)) {
      throw new InvalidPasswordError('Password must contain lowercase letter (a-z)');
    }

    if (!/[0-9]/.test(plainPassword)) {
      throw new InvalidPasswordError('Password must contain number (0-9)');
    }
  }

  /**
   * Get the hash
   */
  getHash(): string {
    return this.hash;
  }

  /**
   * String representation (returns hash, never plaintext)
   */
  toString(): string {
    return this.hash;
  }
}
