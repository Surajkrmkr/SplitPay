import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as groupsService from '../groups/groups.service';
import { sendSuccess } from '../../utils/response';

export async function getInviteInfo(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const info = await groupsService.getInviteInfo(req.params.code);
    sendSuccess(res, info, 'Invite info retrieved');
  } catch (err) { next(err); }
}

export async function joinViaInvite(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    const group = await groupsService.joinViaInvite(req.params.code, authReq.user.userId);
    sendSuccess(res, group, 'Joined group successfully');
  } catch (err) { next(err); }
}
