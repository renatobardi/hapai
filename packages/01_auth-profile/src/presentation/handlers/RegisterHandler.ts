import { RegisterUseCase } from '../../application/use-cases/register/RegisterUseCase';
import { RegisterRequest } from '../../application/dto/RegisterRequest';
import { ErrorMapper } from '../errors/ErrorMapper';

/**
 * Handler: Register
 * Orchestrates HTTP request → RegisterUseCase → HTTP response
 */
export class RegisterHandler {
  constructor(private registerUseCase: RegisterUseCase) {}

  /**
   * Handle registration HTTP request
   */
  async handle(body: Record<string, unknown>): Promise<{
    status: number;
    body: unknown;
  }> {
    try {
      // Step 1: Validate request structure
      if (!body.email || !body.password || !body.name) {
        return {
          status: 400,
          body: { error: 'Email, password, and name are required' }
        };
      }

      // Step 2: Create request DTO (will validate format)
      const request = new RegisterRequest(
        String(body.email),
        String(body.password),
        String(body.name)
      );

      // Step 3: Execute use case
      const response = await this.registerUseCase.execute(request);

      // Step 4: Return success response (201 Created)
      return {
        status: 201,
        body: {
          token: response.token,
          user: response.user
        }
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
