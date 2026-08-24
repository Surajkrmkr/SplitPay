import { NotificationType } from '@prisma/client';
import { prisma } from '../../prisma/client';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface CreateNotificationData {
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  groupId?: string;
  actorName?: string;
  actorAvatar?: string;
  data?: Record<string, string>;
}

// ── Token Management ──────────────────────────────────────────────────────────

export async function upsertFcmToken(
  userId: string,
  token: string,
  deviceType: string
): Promise<void> {
  await prisma.fcmToken.upsert({
    where: { token },
    update: { userId, deviceType },
    create: { userId, token, deviceType },
  });
}

export async function deleteFcmToken(token: string): Promise<void> {
  await prisma.fcmToken.deleteMany({ where: { token } });
}

export async function deleteUserFcmTokens(userId: string): Promise<void> {
  await prisma.fcmToken.deleteMany({ where: { userId } });
}

export async function getUserFcmTokens(userId: string): Promise<string[]> {
  const rows = await prisma.fcmToken.findMany({
    where: { userId },
    select: { token: true },
  });
  return rows.map((r) => r.token);
}

/** Returns all FCM tokens belonging to the given user IDs. */
export async function getUserFcmTokensFor(userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];
  const rows = await prisma.fcmToken.findMany({
    where: { userId: { in: userIds } },
    select: { token: true },
  });
  return rows.map((r) => r.token);
}

// ── Notifications CRUD ────────────────────────────────────────────────────────

export async function createNotification(data: CreateNotificationData) {
  return prisma.notification.create({
    data: {
      userId: data.userId,
      type: data.type,
      title: data.title,
      body: data.body,
      groupId: data.groupId,
      actorName: data.actorName,
      actorAvatar: data.actorAvatar,
      data: data.data ?? {},
    },
  });
}

/** Batch-create notifications for multiple recipients. */
export async function createNotifications(items: CreateNotificationData[]): Promise<void> {
  if (items.length === 0) return;
  await prisma.notification.createMany({
    data: items.map((d) => ({
      userId: d.userId,
      type: d.type,
      title: d.title,
      body: d.body,
      groupId: d.groupId,
      actorName: d.actorName,
      actorAvatar: d.actorAvatar,
      data: d.data ?? {},
    })),
    skipDuplicates: true,
  });
}

export async function findUserNotifications(userId: string, page: number, limit: number) {
  const [items, total] = await Promise.all([
    prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.notification.count({ where: { userId } }),
  ]);
  return { items, total };
}

export async function markNotificationRead(notificationId: string, userId: string): Promise<void> {
  await prisma.notification.updateMany({
    where: { id: notificationId, userId },
    data: { isRead: true },
  });
}

export async function markAllNotificationsRead(userId: string): Promise<void> {
  await prisma.notification.updateMany({
    where: { userId, isRead: false },
    data: { isRead: true },
  });
}

export async function deleteNotification(notificationId: string, userId: string): Promise<void> {
  await prisma.notification.deleteMany({
    where: { id: notificationId, userId },
  });
}

export async function deleteAllNotifications(userId: string): Promise<void> {
  await prisma.notification.deleteMany({ where: { userId } });
}
