import { GetProfileRequest } from '../../dto/GetProfileRequest';
import { GetProfileResponse } from '../../dto/GetProfileResponse';
import { UserMapper } from '../../dto/mappers/UserMapper';
import { IUserRepository } from '../../../domain/repositories/IUserRepository';
import { UserId } from '../../../domain/value-objects/UserId';
import { UserNotFoundError } from '../../../domain/errors/UserNotFoundError';

/**
 * UseCase: Get Profile
 * Retrieves authenticated user's profile information
 */
export class GetProfileUseCase {
  constructor(private userRepository: IUserRepository) {}

  async execute(request: GetProfileRequest): Promise<GetProfileResponse> {
    // Step 1: Create UserId value object
    const userId = UserId.fromString(request.userId);

    // Step 2: Fetch user from repository
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new UserNotFoundError('User not found');
    }

    // Step 3: Return response with mapped user data
    return new GetProfileResponse(UserMapper.toProfileResponse(user));
  }
}
