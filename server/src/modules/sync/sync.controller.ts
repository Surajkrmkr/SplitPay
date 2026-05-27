import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as syncService from './sync.service';
import { sendSuccess } from '../../utils/response';
import { SyncPushInput, SyncPullQuery } from '../../validations/sync.validation';

export async function pushChanges(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const result = await syncService.pushChanges(userId, req.body as SyncPushInput);
    sendSuccess(res, result, 'Sync push completed');
  } catch (err) {
    next(err);
  }
}

export async function pullChanges(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const result = await syncService.pullChanges(userId, req.query as unknown as SyncPullQuery);
    sendSuccess(res, result, 'Sync pull completed');
  } catch (err) {
    next(err);
  }
}
