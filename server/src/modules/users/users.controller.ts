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

export async function updateMe(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const user = await usersService.updateMe(req.user.userId, req.body);
    sendSuccess(res, user, 'User profile updated');
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

export async function deleteMe(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    await usersService.deleteMe(req.user.userId);
    sendSuccess(res, null, 'Account deleted successfully');
  } catch (err) {
    next(err);
  }
}
