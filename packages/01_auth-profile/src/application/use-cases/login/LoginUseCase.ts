import { LoginRequest } from '../../dto/LoginRequest';
import { LoginResponse } from '../../dto/LoginResponse';
import { UserMapper } from '../../dto/mappers/UserMapper';
import { IUserRepository } from '../../../domain/repositories/IUserRepository';
import { Email } from '../../../domain/value-objects/Email';
import { InvalidCredentialsError } from '../../../domain/errors/InvalidCredentialsError';
import type { IPasswordHasher } from '../../ports/IPasswordHasher';
import type { ITokenGenerator } from '../../ports/ITokenGenerator';

/**
 * UseCase: Login
 * Orchestrates user authentication with domain logic and infrastructure adapters
 * Returns authenticated token and user data
 */
export class LoginUseCase {
  constructor(
    private userRepository: IUserRepository,
    private passwordHasher: IPasswordHasher,
    private tokenGenerator: ITokenGenerator
  ) {}

  async execute(request: LoginRequest): Promise<LoginResponse> {
    // Step 1: Create Email value object (validates format)
    const email = Email.fromString(request.email);

    // Step 2: Find user by email
    const user = await this.userRepository.findByEmail(email);
    if (!user) {
      // Security: Use generic message to prevent user enumeration
      throw new InvalidCredentialsError('Invalid email or password');
    }

    // Step 3: Verify password
    const passwordHash = user.getPasswordHash();
    const isPasswordValid = await this.passwordHasher.compare(
      request.password,
      passwordHash
    );
    if (!isPasswordValid) {
      throw new InvalidCredentialsError('Invalid email or password');
    }

    // Step 4: Update last login timestamp
    user.recordLogin();

    // Step 5: Persist user (update lastLogin)
    await this.userRepository.save(user);

    // Step 6: Generate authentication token
    const token = await this.tokenGenerator.generate({
      userId: user.id.getValue(),
      email: user.email.getValue(),
      roles: user.roles.map(r => r.getValue())
    });

    // Step 7: Return response with token and user data
    return new LoginResponse(token, UserMapper.toLoginResponse(user));
  }
}
