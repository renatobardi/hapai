import { LoginUseCase } from '../../application/use-cases/login/LoginUseCase';
import { LoginRequest } from '../../application/dto/LoginRequest';
import { ErrorMapper } from '../errors/ErrorMapper';

/**
 * Handler: Login
 * Orchestrates HTTP request → LoginUseCase → HTTP response
 */
export class LoginHandler {
  constructor(private loginUseCase: LoginUseCase) {}

  /**
   * Handle login HTTP request
   */
  async handle(body: Record<string, unknown>): Promise<{
    status: number;
    body: unknown;
  }> {
    try {
      // Step 1: Validate request structure
      if (!body.email || !body.password) {
        return {
          status: 400,
          body: { error: 'Email and password are required' }
        };
      }

      // Step 2: Create request DTO (will validate format)
      const request = new LoginRequest(
        String(body.email),
        String(body.password)
      );

      // Step 3: Execute use case
      const response = await this.loginUseCase.execute(request);

      // Step 4: Return success response
      return {
        status: 200,
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
