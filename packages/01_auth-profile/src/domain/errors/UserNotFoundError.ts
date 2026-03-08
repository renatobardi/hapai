import { DomainError } from './DomainError';

export class UserNotFoundError extends DomainError {
  constructor(message: string = 'User not found') {
    super(message, 'USER_NOT_FOUND');
    Object.setPrototypeOf(this, UserNotFoundError.prototype);
  }
}
