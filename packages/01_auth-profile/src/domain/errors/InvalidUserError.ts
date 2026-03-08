import { DomainError } from './DomainError';

export class InvalidUserError extends DomainError {
  constructor(message: string = 'Invalid user data') {
    super(message, 'INVALID_USER');
    Object.setPrototypeOf(this, InvalidUserError.prototype);
  }
}
