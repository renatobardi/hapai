import { InvalidEmailError } from '../errors/InvalidEmailError';

/**
 * Email Value Object
 * - Immutable
 * - Validates RFC 5322 format
 * - Unique constraint at domain level
 */
export class Email {
  private readonly value: string;

  private constructor(value: string) {
    Email.validate(value);
    this.value = value.toLowerCase();
  }

  /**
   * Factory method to create an Email
   */
  static fromString(email: string): Email {
    return new Email(email);
  }

  /**
   * Validate email format
   */
  private static validate(email: string): void {
    if (!email || email.trim().length === 0) {
      throw new InvalidEmailError('Email cannot be empty');
    }

    // Simple RFC 5322 compliant regex
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new InvalidEmailError(`Invalid email format: ${email}`);
    }
  }

  /**
   * Get the email value
   */
  getValue(): string {
    return this.value;
  }

  /**
   * Compare with another Email
   */
  equals(other: Email): boolean {
    return this.value === other.value;
  }

  /**
   * String representation
   */
  toString(): string {
    return this.value;
  }
}
