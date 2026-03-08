/**
 * DTO: Register Response
 * Output data from register use case
 */
export interface RegisterResponseData {
  id: string;
  email: string;
  name: string;
  roles: string[];
}

export class RegisterResponse {
  constructor(
    public readonly token: string,
    public readonly user: RegisterResponseData
  ) {}
}
