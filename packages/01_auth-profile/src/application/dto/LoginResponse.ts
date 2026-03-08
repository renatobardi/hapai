/**
 * DTO: Login Response
 * Output data from login use case
 */
export interface LoginResponseData {
  id: string;
  email: string;
  name: string;
  roles: string[];
}

export class LoginResponse {
  constructor(
    public readonly token: string,
    public readonly user: LoginResponseData
  ) {}
}
