import { User } from '../entities/User';
import { UserId } from '../value-objects/UserId';
import { Email } from '../value-objects/Email';

/**
 * IUserRepository Port
 * - Abstracts persistence layer
 * - Domain doesn't know HOW data is persisted
 * - Only knows WHAT operations are possible
 * - Implementation in infrastructure layer
 */
export interface IUserRepository {
  /**
   * Save (create or update) a user
   */
  save(user: User): Promise<void>;

  /**
   * Find user by ID
   */
  findById(id: UserId): Promise<User | null>;

  /**
   * Find user by email (unique constraint)
   */
  findByEmail(email: Email): Promise<User | null>;

  /**
   * Delete user
   */
  delete(id: UserId): Promise<void>;

  /**
   * Check if user exists
   */
  exists(id: UserId): Promise<boolean>;

  /**
   * Get total count of users
   */
  count(): Promise<number>;
}
