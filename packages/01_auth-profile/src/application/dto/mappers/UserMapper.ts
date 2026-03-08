import { User } from '../../../domain/entities/User';
import { LoginResponseData } from '../LoginResponse';
import { RegisterResponseData } from '../RegisterResponse';
import { GetProfileResponseData } from '../GetProfileResponse';

/**
 * Mapper: Entity <-> DTO
 * Converts User entities to data transfer objects
 * This keeps domain logic isolated from API contracts
 */
export class UserMapper {
  /**
   * Map User entity to login response DTO
   */
  static toLoginResponse(user: User): LoginResponseData {
    return {
      id: user.id.getValue(),
      email: user.email.getValue(),
      name: user.name,
      roles: user.roles.map(r => r.getValue())
    };
  }

  /**
   * Map User entity to register response DTO
   */
  static toRegisterResponse(user: User): RegisterResponseData {
    return {
      id: user.id.getValue(),
      email: user.email.getValue(),
      name: user.name,
      roles: user.roles.map(r => r.getValue())
    };
  }

  /**
   * Map User entity to profile response DTO
   */
  static toProfileResponse(user: User): GetProfileResponseData {
    return {
      id: user.id.getValue(),
      email: user.email.getValue(),
      name: user.name,
      roles: user.roles.map(r => r.getValue()),
      createdAt: user.createdAt.toISOString(),
      lastLogin: user.lastLogin ? user.lastLogin.toISOString() : null
    };
  }
}
