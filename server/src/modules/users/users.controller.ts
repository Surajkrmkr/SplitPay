import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as usersService from './users.service';
import { sendSuccess } from '../../utils/response';

export async function getMe(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const user = await usersService.getMe(req.user.userId);
    sendSuccess(res, user, 'User profile retrieved');
  } catch (err) {
    next(err);
  }
}

export async function searchUsers(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const { q } = req.query as { q: string };
    const users = await usersService.search(q, req.user.userId);
    sendSuccess(res, users, 'Users found');
  } catch (err) {
    next(err);
  }
}
