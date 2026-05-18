import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as activityService from './activity.service';
import { sendSuccess } from '../../utils/response';

export async function getGroupActivity(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    const { id: groupId } = req.params;
    const activities = await activityService.getGroupActivity(groupId, authReq.user.userId);
    sendSuccess(res, activities, 'Activity retrieved');
  } catch (err) {
    next(err);
  }
}
