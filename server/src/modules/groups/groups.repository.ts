import { prisma } from '../../prisma/client';
import { Group, GroupMember, GroupRole } from '@prisma/client';

export interface CreateGroupData {
  name: string;
  description?: string;
  avatar?: string;
  createdById: string;
}

export type GroupWithMembers = Group & {
  members: (GroupMember & {
    user: {
      id: string;
      name: string;
      email: string;
      avatar: string | null;
    };
  })[];
  _count: { members: number; expenses: number };
};

export async function createGroup(data: CreateGroupData): Promise<Group> {
  return prisma.group.create({ data });
}

export async function findGroupById(groupId: string): Promise<GroupWithMembers | null> {
  return prisma.group.findUnique({
    where: { id: groupId },
    include: {
      members: {
        include: {
          user: {
            select: { id: true, name: true, email: true, avatar: true },
          },
        },
        orderBy: { joinedAt: 'asc' },
      },
      _count: {
        select: { members: true, expenses: true },
      },
    },
  });
}

export async function findUserGroups(userId: string): Promise<GroupWithMembers[]> {
  return prisma.group.findMany({
    where: {
      members: { some: { userId } },
    },
    include: {
      members: {
        include: {
          user: {
            select: { id: true, name: true, email: true, avatar: true },
          },
        },
        orderBy: { joinedAt: 'asc' },
      },
      _count: {
        select: { members: true, expenses: true },
      },
    },
    orderBy: { updatedAt: 'desc' },
  });
}

export async function addMember(
  groupId: string,
  userId: string,
  role: GroupRole = GroupRole.MEMBER
): Promise<GroupMember> {
  return prisma.groupMember.create({
    data: { groupId, userId, role },
  });
}

export async function removeMember(groupId: string, userId: string): Promise<void> {
  await prisma.groupMember.deleteMany({ where: { groupId, userId } });
}

export async function findMember(groupId: string, userId: string): Promise<GroupMember | null> {
  return prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId } },
  });
}

export async function isMember(groupId: string, userId: string): Promise<boolean> {
  const member = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId } },
  });
  return !!member;
}

export async function updateGroup(
  groupId: string,
  data: Partial<{ name: string; description: string; avatar: string }>
): Promise<Group> {
  return prisma.group.update({ where: { id: groupId }, data });
}

export async function deleteGroup(groupId: string): Promise<void> {
  await prisma.group.delete({ where: { id: groupId } });
}

export async function updateMemberRole(
  groupId: string,
  userId: string,
  role: GroupRole
): Promise<GroupMember> {
  return prisma.groupMember.update({
    where: { groupId_userId: { groupId, userId } },
    data: { role },
  });
}

export async function createInvite(data: {
  code: string;
  groupId: string;
  createdById: string;
  expiresAt: Date;
  maxUses: number;
}) {
  return prisma.groupInvite.create({ data });
}

export async function deactivateGroupInvites(groupId: string): Promise<void> {
  await prisma.groupInvite.updateMany({
    where: { groupId, active: true },
    data: { active: false },
  });
}

export async function findInviteByCode(code: string) {
  return prisma.groupInvite.findUnique({
    where: { code },
    include: {
      group: { include: { members: { include: { user: { select: { id: true, name: true, avatar: true } } } } } },
      createdBy: { select: { id: true, name: true, avatar: true } },
    },
  });
}

export async function incrementInviteUsage(code: string) {
  return prisma.groupInvite.update({
    where: { code },
    data: { usedCount: { increment: 1 } },
  });
}
