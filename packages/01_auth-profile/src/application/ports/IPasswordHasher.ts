import { Password } from '../../domain/value-objects/Password';

/**
 * Port: Password Hashing
 * Abstracts the password hashing mechanism (bcrypt, scrypt, etc.)
 */
export interface IPasswordHasher {
  /**
   * Hash a plaintext password
   * @throws InvalidPasswordError if password doesn't meet strength requirements
   */
  hash(plainPassword: string): Promise<Password>;

  /**
   * Compare a plaintext password against a hash
   */
  compare(plainPassword: string, hash: string): Promise<boolean>;
}
