import { GetProfileUseCase } from '../../application/use-cases/get-profile/GetProfileUseCase';
import { GetProfileRequest } from '../../application/dto/GetProfileRequest';
import { ErrorMapper } from '../errors/ErrorMapper';

/**
 * Handler: Get Profile
 * Orchestrates HTTP request → GetProfileUseCase → HTTP response
 */
export class ProfileHandler {
  constructor(private getProfileUseCase: GetProfileUseCase) {}

  /**
   * Handle get profile HTTP request
   * Expects userId to be extracted from JWT token
   */
  async handle(userId: string): Promise<{
    status: number;
    body: unknown;
  }> {
    try {
      // Step 1: Validate userId parameter
      if (!userId) {
        return {
          status: 400,
          body: { error: 'User ID is required' }
        };
      }

      // Step 2: Create request DTO (will validate format)
      const request = new GetProfileRequest(userId);

      // Step 3: Execute use case
      const response = await this.getProfileUseCase.execute(request);

      // Step 4: Return success response
      return {
        status: 200,
        body: response.user
      };
    } catch (error) {
      // Step 5: Map domain errors to HTTP errors
      const errorResponse = ErrorMapper.toHttpResponse(error);
      return {
        status: errorResponse.status,
        body: errorResponse.body
      };
    }
  }
}
