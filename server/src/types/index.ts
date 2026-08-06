import { Request } from 'express';

export interface AuthenticatedRequest extends Request {
  user: {
    userId: string;
    email: string;
  };
}

/** Normalized user info extracted from a verified Firebase ID token (any provider). */
export interface FirebaseTokenUser {
  uid: string;
  email: string;
  name: string;
  picture?: string;
  email_verified?: boolean;
  firebase: {
    sign_in_provider: string;
  };
}

/** @deprecated Use FirebaseTokenUser */
export type GoogleUser = FirebaseTokenUser;

export interface PaginationQuery {
  page?: number;
  limit?: number;
}

export interface PaginationMeta {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}
