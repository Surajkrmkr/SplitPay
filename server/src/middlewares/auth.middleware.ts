import { Request, Response, NextFunction } from 'express';
import { verifyAccessToken } from '../utils/jwt';
import { UnauthorizedError } from '../utils/app-error';
import { AuthenticatedRequest } from '../types';

export function authenticate(req: Request, _res: Response, next: NextFunction): void {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedError('Authorization header missing or malformed');
    }

    const token = authHeader.slice(7);

    if (!token) {
      throw new UnauthorizedError('Access token not provided');
    }

    const payload = verifyAccessToken(token);

    (req as AuthenticatedRequest).user = {
      userId: payload.userId,
      email: payload.email,
    };

    next();
  } catch (err) {
    next(err);
  }
}
