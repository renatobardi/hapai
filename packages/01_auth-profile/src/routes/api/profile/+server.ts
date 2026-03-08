import type { RequestHandler } from './$types';
import { ProfileHandler } from '../../../presentation/handlers/ProfileHandler';
import { createAuthenticateMiddleware, extractAuthHeader } from '../../../presentation/middleware/authenticate';
import { ErrorMapper } from '../../../presentation/errors/ErrorMapper';

/**
 * GET /api/profile
 * Returns authenticated user's profile
 * Requires valid JWT token in Authorization header
 */
export const GET: RequestHandler = async ({ request }) => {
  try {
    // Get dependencies from somewhere (DI container or globals)
    const deps = (global as any).__authDeps;

    if (!deps) {
      return new Response(JSON.stringify({ error: 'Service not initialized' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Step 1: Authenticate request via JWT token
    const authenticate = createAuthenticateMiddleware(deps.tokenGenerator);
    const authHeader = extractAuthHeader(request);
    const auth = authenticate(authHeader);

    if (!auth) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Step 2: Handle get profile request
    const profileHandler = new ProfileHandler(deps.getProfileUseCase);
    const result = await profileHandler.handle(auth.userId);

    return new Response(JSON.stringify(result.body), {
      status: result.status,
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    const errorResponse = ErrorMapper.toHttpResponse(error);
    return new Response(JSON.stringify(errorResponse.body), {
      status: errorResponse.status,
      headers: { 'Content-Type': 'application/json' }
    });
  }
};
