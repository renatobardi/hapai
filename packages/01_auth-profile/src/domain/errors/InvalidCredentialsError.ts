import { DomainError } from './DomainError';

export class InvalidCredentialsError extends DomainError {
  constructor(message: string = 'Invalid credentials') {
    super(message, 'INVALID_CREDENTIALS');
    Object.setPrototypeOf(this, InvalidCredentialsError.prototype);
  }
}
