import { Response, NextFunction, Request } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as groupsService from './groups.service';
import { sendSuccess, sendCreated } from '../../utils/response';
import { CreateGroupInput, AddMemberInput, UpdateGroupInput, UpdateMemberRoleInput } from '../../validations/group.validation';

export async function createGroup(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const group = await groupsService.createGroup(req.user.userId, req.body as CreateGroupInput);
    sendCreated(res, group, 'Group created successfully');
  } catch (err) {
    next(err);
  }
}

export async function getGroups(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const groups = await groupsService.getGroups(req.user.userId);
    sendSuccess(res, groups, 'Groups retrieved');
  } catch (err) {
    next(err);
  }
}

export async function getGroup(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const { id } = req.params;
    const group = await groupsService.getGroup(id, req.user.userId);
    sendSuccess(res, group, 'Group retrieved');
  } catch (err) {
    next(err);
  }
}

export async function addMember(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const { id } = req.params;
    await groupsService.addMember(id, req.user.userId, req.body as AddMemberInput);
    sendSuccess(res, null, 'Member added successfully');
  } catch (err) {
    next(err);
  }
}

export async function removeMember(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const { id, memberId } = req.params;
    await groupsService.removeMember(id, req.user.userId, memberId);
    sendSuccess(res, null, 'Member removed successfully');
  } catch (err) {
    next(err);
  }
}

export async function updateGroup(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
  try {
    const group = await groupsService.updateGroup(req.params.id, req.user.userId, req.body as UpdateGroupInput);
    sendSuccess(res, group, 'Group updated successfully');
  } catch (err) { next(err); }
}

export async function deleteGroup(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
  try {
    await groupsService.deleteGroup(req.params.id, req.user.userId);
    sendSuccess(res, null, 'Group deleted successfully');
  } catch (err) { next(err); }
}

export async function updateMemberRole(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
  try {
    await groupsService.updateMemberRole(req.params.id, req.user.userId, req.params.memberId, req.body as UpdateMemberRoleInput);
    sendSuccess(res, null, 'Member role updated');
  } catch (err) { next(err); }
}

export async function generateInvite(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await groupsService.generateInvite(req.params.id, req.user.userId);
    sendCreated(res, result, 'Invite created');
  } catch (err) { next(err); }
}

export async function getActiveInvite(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await groupsService.getActiveInvite(req.params.id, req.user.userId);
    sendSuccess(res, result, result ? 'Active invite retrieved' : 'No active invite');
  } catch (err) { next(err); }
}

// Re-export with Request type cast for router compatibility
export function createGroupHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return createGroup(req as AuthenticatedRequest, res, next);
}

export function getGroupsHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return getGroups(req as AuthenticatedRequest, res, next);
}

export function getGroupHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return getGroup(req as AuthenticatedRequest, res, next);
}

export function addMemberHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return addMember(req as AuthenticatedRequest, res, next);
}

export function removeMemberHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return removeMember(req as AuthenticatedRequest, res, next);
}
export function updateGroupHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return updateGroup(req as AuthenticatedRequest, res, next);
}
export function deleteGroupHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return deleteGroup(req as AuthenticatedRequest, res, next);
}
export function updateMemberRoleHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return updateMemberRole(req as AuthenticatedRequest, res, next);
}
export function generateInviteHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return generateInvite(req as AuthenticatedRequest, res, next);
}
export function getActiveInviteHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  return getActiveInvite(req as AuthenticatedRequest, res, next);
}
