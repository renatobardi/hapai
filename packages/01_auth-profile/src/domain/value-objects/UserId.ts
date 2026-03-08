import { randomUUID } from 'crypto';
import { InvalidUserError } from '../errors/InvalidUserError';

/**
 * UserId Value Object
 * - Immutable
 * - UUID v4 format
 * - Represents user identity
 */
export class UserId {
  private readonly value: string;

  private constructor(value: string) {
    UserId.validate(value);
    this.value = value;
  }

  /**
   * Generate a new UserId
   */
  static generate(): UserId {
    return new UserId(randomUUID());
  }

  /**
   * Create UserId from string
   */
  static fromString(id: string): UserId {
    return new UserId(id);
  }

  /**
   * Validate UUID v4 format
   */
  private static validate(id: string): void {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      throw new InvalidUserError(`Invalid UserId format: ${id}`);
    }
  }

  /**
   * Get the ID value
   */
  getValue(): string {
    return this.value;
  }

  /**
   * Compare with another UserId
   */
  equals(other: UserId): boolean {
    return this.value === other.value;
  }

  /**
   * String representation
   */
  toString(): string {
    return this.value;
  }
}
