/**
 * Base class for all domain errors
 * Domain errors represent business rule violations
 */
export abstract class DomainError extends Error {
  public readonly code: string;

  constructor(message: string, code: string) {
    super(message);
    this.code = code;
    this.name = this.constructor.name;
    Object.setPrototypeOf(this, DomainError.prototype);
  }

  toString(): string {
    return `${this.name}: ${this.message}`;
  }
}
