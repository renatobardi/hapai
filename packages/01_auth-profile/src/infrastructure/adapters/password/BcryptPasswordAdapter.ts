import { Password, InvalidPasswordError } from '../../../domain';

/**
 * BcryptPasswordAdapter
 * - Adapts bcrypt hashing to domain Password value object
 * - Responsible for hashing plaintext passwords
 * - Implements password comparison
 */
export class BcryptPasswordAdapter {
  private readonly saltRounds = 10;

  /**
   * Hash plaintext password
   * Note: Real implementation would use bcrypt library
   */
  async hash(plainPassword: string): Promise<Password> {
    // Validate password strength before hashing
    Password.validateStrength(plainPassword);

    // Mock hashing (in reality, use bcrypt.hash)
    // const hash = await bcrypt.hash(plainPassword, this.saltRounds);
    const hash = this.mockBcryptHash(plainPassword);

    return Password.fromPlaintext(hash);
  }

  /**
   * Verify plaintext password against hash
   * Note: Real implementation would use bcrypt.compare
   */
  async compare(plainPassword: string, hash: string): Promise<boolean> {
    // In reality: return await bcrypt.compare(plainPassword, hash);
    return this.mockBcryptCompare(plainPassword, hash);
  }

  /**
   * Mock bcrypt hash for demonstration
   * In production, use: import bcrypt from 'bcrypt'
   */
  private mockBcryptHash(plainPassword: string): string {
    // Simple mock that creates a fake bcrypt-like hash
    // Real implementation would use bcrypt.hash()
    const timestamp = Date.now();
    const salt = `$2b$10$${timestamp}${Math.random()}`;
    const mockHash = `${salt}${Buffer.from(plainPassword).toString('base64').slice(0, 20)}`;
    return mockHash;
  }

  /**
   * Mock bcrypt compare for demonstration
   * In production, use: import bcrypt from 'bcrypt'
   */
  private mockBcryptCompare(plainPassword: string, hash: string): boolean {
    // This is just a mock for testing
    // Real implementation would use bcrypt.compare()
    // For now, return true if the plainPassword is valid
    try {
      Password.validateStrength(plainPassword);
      return hash.length > 0; // Mock: if hash exists and password is valid
    } catch {
      return false;
    }
  }
}
