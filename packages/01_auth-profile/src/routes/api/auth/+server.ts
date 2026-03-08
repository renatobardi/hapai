import type { RequestHandler } from './$types';
import { LoginHandler } from '../../../presentation/handlers/LoginHandler';
import { RegisterHandler } from '../../../presentation/handlers/RegisterHandler';
import { ErrorMapper } from '../../../presentation/errors/ErrorMapper';

/**
 * POST /api/auth
 * Handles both login and register based on query parameter
 * ?action=login or ?action=register
 */
export const POST: RequestHandler = async ({ request, url }) => {
  try {
    // Get dependencies from somewhere (DI container or globals)
    // For now, we'll create them here (should come from proper DI setup)
    const deps = (global as any).__authDeps;

    if (!deps) {
      return new Response(JSON.stringify({ error: 'Service not initialized' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Parse request body
    const body = await request.json().catch(() => ({}));

    // Determine action from query parameter
    const action = url.searchParams.get('action') || 'login';

    if (action === 'login') {
      // Handle login
      const loginHandler = new LoginHandler(deps.loginUseCase);
      const result = await loginHandler.handle(body);

      return new Response(JSON.stringify(result.body), {
        status: result.status,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    if (action === 'register') {
      // Handle register
      const registerHandler = new RegisterHandler(deps.registerUseCase);
      const result = await registerHandler.handle(body);

      return new Response(JSON.stringify(result.body), {
        status: result.status,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify({ error: 'Invalid action' }), {
      status: 400,
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
