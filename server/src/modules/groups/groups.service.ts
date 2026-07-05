import { GroupRole } from '@prisma/client';
import { ForbiddenError, NotFoundError, ConflictError, BadRequestError } from '../../utils/app-error';
import * as groupsRepository from './groups.repository';
import { GroupWithMembers } from './groups.repository';
import * as activityRepository from '../activity/activity.repository';
import * as notificationsService from '../notifications/notifications.service';
import { CreateGroupInput, AddMemberInput, UpdateGroupInput, UpdateMemberRoleInput } from '../../validations/group.validation';
import crypto from 'crypto';

export async function createGroup(
  userId: string,
  input: CreateGroupInput
): Promise<GroupWithMembers> {
  // Create the group
  const group = await groupsRepository.createGroup({
    ...input,
    createdById: userId,
  });

  // Add creator as ADMIN
  await groupsRepository.addMember(group.id, userId, GroupRole.ADMIN);

  // Log GROUP_CREATED activity
  await activityRepository.createActivity({
    groupId: group.id,
    userId,
    type: 'GROUP_CREATED',
    metadata: { groupName: group.name },
  });

  // Return the fully populated group
  const fullGroup = await groupsRepository.findGroupById(group.id);
  if (!fullGroup) {
    throw new NotFoundError('Group not found after creation');
  }

  return fullGroup;
}

export async function getGroups(userId: string): Promise<GroupWithMembers[]> {
  return groupsRepository.findUserGroups(userId);
}

export async function getGroup(groupId: string, userId: string): Promise<GroupWithMembers> {
  const group = await groupsRepository.findGroupById(groupId);

  if (!group) {
    throw new NotFoundError('Group not found');
  }

  const memberInGroup = await groupsRepository.isMember(groupId, userId);
  if (!memberInGroup) {
    throw new ForbiddenError('You are not a member of this group');
  }

  return group;
}

export async function addMember(
  groupId: string,
  requesterId: string,
  input: AddMemberInput
): Promise<void> {
  const { userId } = input;

  // Verify group exists
  const group = await groupsRepository.findGroupById(groupId);
  if (!group) {
    throw new NotFoundError('Group not found');
  }

  // Only ADMINs can add members
  const requester = await groupsRepository.findMember(groupId, requesterId);
  if (!requester || requester.role !== GroupRole.ADMIN) {
    throw new ForbiddenError('Only group admins can add members');
  }

  // Check if user is already a member
  const alreadyMember = await groupsRepository.isMember(groupId, userId);
  if (alreadyMember) {
    throw new ConflictError('User is already a member of this group');
  }

  await groupsRepository.addMember(groupId, userId);

  // Log MEMBER_JOINED activity, attributed to the joining user (not the admin
  // who added them) so the activity feed reads "X joined the group".
  await activityRepository.createActivity({
    groupId,
    userId,
    type: 'MEMBER_JOINED',
    metadata: { addedById: requesterId },
  });

  // Notify added user (fire-and-forget)
  const requesterUser = group.members.find((m) => m.userId === requesterId)?.user;
  notificationsService
    .notifyAddedToGroup({
      userId,
      groupId,
      groupName: group.name,
      addedByName: requesterUser?.name ?? 'An admin',
    })
    .catch(() => {});
}

export async function updateGroup(
  groupId: string,
  requesterId: string,
  input: UpdateGroupInput
): Promise<GroupWithMembers> {
  const group = await groupsRepository.findGroupById(groupId);
  if (!group) throw new NotFoundError('Group not found');

  const requester = await groupsRepository.findMember(groupId, requesterId);
  if (!requester || requester.role !== GroupRole.ADMIN) {
    throw new ForbiddenError('Only group admins can update the group');
  }

  await groupsRepository.updateGroup(groupId, input);
  const updated = await groupsRepository.findGroupById(groupId);
  return updated!;
}

export async function deleteGroup(groupId: string, requesterId: string): Promise<void> {
  const group = await groupsRepository.findGroupById(groupId);
  if (!group) throw new NotFoundError('Group not found');

  const requester = await groupsRepository.findMember(groupId, requesterId);
  if (!requester || requester.role !== GroupRole.ADMIN) {
    throw new ForbiddenError('Only group admins can delete the group');
  }

  await groupsRepository.deleteGroup(groupId);
}

export async function updateMemberRole(
  groupId: string,
  requesterId: string,
  targetUserId: string,
  input: UpdateMemberRoleInput
): Promise<void> {
  const group = await groupsRepository.findGroupById(groupId);
  if (!group) throw new NotFoundError('Group not found');

  const requester = await groupsRepository.findMember(groupId, requesterId);
  if (!requester || requester.role !== GroupRole.ADMIN) {
    throw new ForbiddenError('Only group admins can change member roles');
  }

  const target = await groupsRepository.findMember(groupId, targetUserId);
  if (!target) throw new NotFoundError('Member not found');

  if (requesterId === targetUserId && input.role === GroupRole.MEMBER) {
    const admins = group.members.filter((m) => m.role === GroupRole.ADMIN);
    if (admins.length <= 1) throw new BadRequestError('Group must have at least one admin');
  }

  await groupsRepository.updateMemberRole(groupId, targetUserId, input.role as GroupRole);
}

export async function generateInvite(
  groupId: string,
  requesterId: string
): Promise<{ code: string; expiresAt: Date }> {
  const group = await groupsRepository.findGroupById(groupId);
  if (!group) throw new NotFoundError('Group not found');

  const requester = await groupsRepository.findMember(groupId, requesterId);
  if (!requester) {
    throw new ForbiddenError('You are not a member of this group');
  }

  const code = crypto.randomBytes(4).toString('hex').toUpperCase();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

  // Only one invite code should be valid per group at a time.
  await groupsRepository.deactivateGroupInvites(groupId);
  await groupsRepository.createInvite({ code, groupId, createdById: requesterId, expiresAt, maxUses: 50 });
  return { code, expiresAt };
}

export async function getActiveInvite(
  groupId: string,
  requesterId: string
): Promise<{ code: string; expiresAt: Date } | null> {
  const group = await groupsRepository.findGroupById(groupId);
  if (!group) throw new NotFoundError('Group not found');

  const requester = await groupsRepository.findMember(groupId, requesterId);
  if (!requester) {
    throw new ForbiddenError('You are not a member of this group');
  }

  const invite = await groupsRepository.findActiveInviteByGroupId(groupId);
  if (!invite) return null;
  return { code: invite.code, expiresAt: invite.expiresAt };
}

export async function joinViaInvite(code: string, userId: string): Promise<GroupWithMembers> {
  const invite = await groupsRepository.findInviteByCode(code);
  if (!invite) throw new NotFoundError('Invite code not found');
  if (!invite.active) throw new BadRequestError('Invite code is no longer active');
  if (invite.expiresAt < new Date()) throw new BadRequestError('Invite code has expired');
  if (invite.usedCount >= invite.maxUses) throw new BadRequestError('Invite code has reached its usage limit');

  const alreadyMember = await groupsRepository.isMember(invite.groupId, userId);
  if (alreadyMember) throw new ConflictError('You are already a member of this group');

  await groupsRepository.addMember(invite.groupId, userId, GroupRole.MEMBER);
  await groupsRepository.incrementInviteUsage(code);

  await activityRepository.createActivity({
    groupId: invite.groupId,
    userId,
    type: 'MEMBER_JOINED',
    metadata: { via: 'invite', code },
  });

  const group = await groupsRepository.findGroupById(invite.groupId);

  // Notify the joining user that they were added to the group
  notificationsService
    .notifyAddedToGroup({
      userId,
      groupId: invite.groupId,
      groupName: invite.group.name,
      addedByName: invite.createdBy.name,
    })
    .catch(() => {});

  // Notify the invite creator that their invite was accepted
  const joiner = group?.members.find((m) => m.userId === userId);
  if (joiner && invite.createdById !== userId) {
    notificationsService
      .notifyMemberJoined({
        inviterId: invite.createdById,
        groupId: invite.groupId,
        groupName: invite.group.name,
        joinerName: joiner.user.name,
      })
      .catch(() => {});
  }

  return group!;
}

export async function getInviteInfo(code: string) {
  const invite = await groupsRepository.findInviteByCode(code);
  if (!invite) throw new NotFoundError('Invite code not found');
  if (!invite.active) throw new BadRequestError('Invite code is no longer active');
  if (invite.expiresAt < new Date()) throw new BadRequestError('Invite code has expired');
  if (invite.usedCount >= invite.maxUses) throw new BadRequestError('Invite code has reached its usage limit');
  return {
    code: invite.code,
    groupName: invite.group.name,
    groupDescription: invite.group.description,
    memberCount: invite.group.members.length,
    invitedBy: invite.createdBy.name,
    expiresAt: invite.expiresAt,
  };
}

export async function removeMember(
  groupId: string,
  requesterId: string,
  memberId: string
): Promise<void> {
  // Verify group exists
  const group = await groupsRepository.findGroupById(groupId);
  if (!group) {
    throw new NotFoundError('Group not found');
  }

  // Verify the target member exists in group
  const targetMember = await groupsRepository.findMember(groupId, memberId);
  if (!targetMember) {
    throw new NotFoundError('Member not found in this group');
  }

  const requester = await groupsRepository.findMember(groupId, requesterId);
  if (!requester) {
    throw new ForbiddenError('You are not a member of this group');
  }

  // ADMIN can remove anyone; MEMBER can only remove themselves
  const isSelf = requesterId === memberId;
  const isAdmin = requester.role === GroupRole.ADMIN;

  if (!isSelf && !isAdmin) {
    throw new ForbiddenError('Only group admins can remove other members');
  }

  await groupsRepository.removeMember(groupId, memberId);

  // Log MEMBER_REMOVED activity
  await activityRepository.createActivity({
    groupId,
    userId: requesterId,
    type: 'MEMBER_REMOVED',
    metadata: { removedUserId: memberId },
  });
}
