/**
 * SvelteKit Server Hooks
 * Sets up Dependency Injection container at startup
 */

import { LoginUseCase } from './application/use-cases/login/LoginUseCase';
import { RegisterUseCase } from './application/use-cases/register/RegisterUseCase';
import { GetProfileUseCase } from './application/use-cases/get-profile/GetProfileUseCase';

// Infrastructure adapters
import { PostgresUserRepository } from './infrastructure/adapters/repositories/PostgresUserRepository';
import { BcryptPasswordAdapter } from './infrastructure/adapters/password/BcryptPasswordAdapter';
import { JwtTokenAdapter } from './infrastructure/adapters/token/JwtTokenAdapter';

/**
 * Initialize Dependency Injection Container
 * This runs once when the server starts
 */
function initializeDependencies() {
  // Get configuration from environment
  const jwtSecret = process.env.JWT_SECRET || 'test-secret-key';

  // Create infrastructure adapters
  const userRepository = new PostgresUserRepository();
  const passwordHasher = new BcryptPasswordAdapter();
  const tokenGenerator = new JwtTokenAdapter(jwtSecret);

  // Create application use cases
  const loginUseCase = new LoginUseCase(userRepository, passwordHasher, tokenGenerator);
  const registerUseCase = new RegisterUseCase(userRepository, passwordHasher, tokenGenerator);
  const getProfileUseCase = new GetProfileUseCase(userRepository);

  return {
    userRepository,
    passwordHasher,
    tokenGenerator,
    loginUseCase,
    registerUseCase,
    getProfileUseCase
  };
}

// Initialize dependencies at server startup
const deps = initializeDependencies();

// Export to global for use in route handlers
if (typeof global !== 'undefined') {
  (global as any).__authDeps = deps;
}

export const handle = async ({ event, resolve }) => {
  // Inject dependencies into event.locals
  event.locals.deps = deps;
  return resolve(event);
};
