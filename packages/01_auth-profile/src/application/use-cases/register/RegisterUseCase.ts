import { RegisterRequest } from '../../dto/RegisterRequest';
import { RegisterResponse } from '../../dto/RegisterResponse';
import { UserMapper } from '../../dto/mappers/UserMapper';
import { User } from '../../../domain/entities/User';
import { Email } from '../../../domain/value-objects/Email';
import { IUserRepository } from '../../../domain/repositories/IUserRepository';
import type { IPasswordHasher } from '../../ports/IPasswordHasher';
import type { ITokenGenerator } from '../../ports/ITokenGenerator';

/**
 * UseCase: Register
 * Orchestrates user registration with password hashing and authentication
 * Returns authenticated token for newly registered user
 */
export class RegisterUseCase {
  constructor(
    private userRepository: IUserRepository,
    private passwordHasher: IPasswordHasher,
    private tokenGenerator: ITokenGenerator
  ) {}

  async execute(request: RegisterRequest): Promise<RegisterResponse> {
    // Step 1: Create Email value object (validates format)
    const email = Email.fromString(request.email);

    // Step 2: Check if user already exists
    const existingUser = await this.userRepository.findByEmail(email);
    if (existingUser) {
      throw new Error('User already registered');
    }

    // Step 3: Hash password
    const passwordHash = await this.passwordHasher.hash(request.password);

    // Step 4: Create new User entity
    const newUser = User.create({
      email,
      passwordHash,
      name: request.name
    });

    // Step 5: Persist user
    await this.userRepository.save(newUser);

    // Step 6: Generate authentication token
    const token = await this.tokenGenerator.generate({
      userId: newUser.id.getValue(),
      email: newUser.email.getValue(),
      roles: newUser.roles.map(r => r.getValue())
    });

    // Step 7: Return response with token and user data
    return new RegisterResponse(token, UserMapper.toRegisterResponse(newUser));
  }
}
