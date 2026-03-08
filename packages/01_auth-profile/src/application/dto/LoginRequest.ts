/**
 * DTO: Login Request
 * Input data for login use case
 */
export class LoginRequest {
  constructor(
    public readonly email: string,
    public readonly password: string
  ) {
    if (!email || !password) {
      throw new Error('Email and password are required');
    }
  }
}
