import { DomainError } from './DomainError';

export class InvalidEmailError extends DomainError {
  constructor(message: string = 'Invalid email format') {
    super(message, 'INVALID_EMAIL');
    Object.setPrototypeOf(this, InvalidEmailError.prototype);
  }
}
