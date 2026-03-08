import { DomainError } from './DomainError';

export class InvalidPasswordError extends DomainError {
  constructor(message: string = 'Invalid password') {
    super(message, 'INVALID_PASSWORD');
    Object.setPrototypeOf(this, InvalidPasswordError.prototype);
  }
}
