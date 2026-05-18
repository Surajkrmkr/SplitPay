import { prisma } from '../../prisma/client';
import { Activity, ActivityType } from '@prisma/client';

export interface CreateActivityData {
  groupId: string;
  userId: string;
  type: ActivityType;
  expenseId?: string;
  settlementId?: string;
  metadata?: Record<string, unknown>;
}

export type ActivityWithUser = Activity & {
  user: { id: string; name: string; email: string; avatar: string | null };
};

export async function createActivity(data: CreateActivityData): Promise<Activity> {
  return prisma.activity.create({ data });
}

export async function findGroupActivities(
  groupId: string,
  limit = 50
): Promise<ActivityWithUser[]> {
  return prisma.activity.findMany({
    where: { groupId },
    include: {
      user: { select: { id: true, name: true, email: true, avatar: true } },
    },
    orderBy: { createdAt: 'desc' },
    take: limit,
  });
}
