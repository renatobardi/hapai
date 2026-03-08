import { User, UserId, Email, IUserRepository } from '../../../domain';

/**
 * PostgresUserRepository Adapter
 * - Implements IUserRepository Port
 * - Abstracts PostgreSQL persistence
 * - Note: Real implementation would use postgres driver
 * - This is a mock for demonstration (TDD: write test first)
 */
export class PostgresUserRepository implements IUserRepository {
  // In-memory storage for now (mock)
  private users: Map<string, User> = new Map();

  constructor() {
    // TODO: Initialize database connection
    // const client = new postgres(process.env.DATABASE_URL);
  }

  async save(user: User): Promise<void> {
    // Mock: store in memory
    this.users.set(user.id.getValue(), user);

    // Real implementation:
    // await client.query(
    //   'INSERT INTO users (id, email, password_hash, name, roles, created_at, last_login) VALUES ($1, $2, $3, $4, $5, $6, $7)',
    //   [user.id.getValue(), user.email.getValue(), user.getPasswordHash(), user.name, ...]
    // );
  }

  async findById(id: UserId): Promise<User | null> {
    // Mock: retrieve from memory
    return this.users.get(id.getValue()) || null;

    // Real implementation:
    // const result = await client.query('SELECT * FROM users WHERE id = $1', [id.getValue()]);
    // if (result.rows.length === 0) return null;
    // return User.reconstruct(result.rows[0]);
  }

  async findByEmail(email: Email): Promise<User | null> {
    // Mock: search in memory
    for (const user of this.users.values()) {
      if (user.email.equals(email)) {
        return user;
      }
    }
    return null;

    // Real implementation:
    // const result = await client.query('SELECT * FROM users WHERE email = $1', [email.getValue()]);
    // if (result.rows.length === 0) return null;
    // return User.reconstruct(result.rows[0]);
  }

  async delete(id: UserId): Promise<void> {
    // Mock: delete from memory
    this.users.delete(id.getValue());

    // Real implementation:
    // await client.query('DELETE FROM users WHERE id = $1', [id.getValue()]);
  }

  async exists(id: UserId): Promise<boolean> {
    // Mock
    return this.users.has(id.getValue());

    // Real implementation:
    // const result = await client.query('SELECT 1 FROM users WHERE id = $1 LIMIT 1', [id.getValue()]);
    // return result.rows.length > 0;
  }

  async count(): Promise<number> {
    // Mock
    return this.users.size;

    // Real implementation:
    // const result = await client.query('SELECT COUNT(*) FROM users');
    // return parseInt(result.rows[0].count);
  }
}
