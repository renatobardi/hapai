/**
 * DTO: Get Profile Response
 * Output data from get profile use case
 */
export interface GetProfileResponseData {
  id: string;
  email: string;
  name: string;
  roles: string[];
  createdAt: string;
  lastLogin: string | null;
}

export class GetProfileResponse {
  constructor(public readonly user: GetProfileResponseData) {}
}
