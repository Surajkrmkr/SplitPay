import * as notificationsRepository from './notifications.repository';
import { sendPushNotification } from '../../utils/fcm';
import {
  RegisterTokenInput,
  GetNotificationsQuery,
} from '../../validations/notification.validation';

async function sendPushNotificationsToUsers(
  userIds: string[],
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  await Promise.all(
    [...new Set(userIds)].map(async (userId) => {
      const [tokens, badge] = await Promise.all([
        notificationsRepository.getUserFcmTokens(userId),
        notificationsRepository.countUnreadNotifications(userId),
      ]);
      if (tokens.length === 0) return;

      sendPushNotification({ tokens, title, body, data, badge }).catch(() => {});
    })
  );
}

// ── Token Management ──────────────────────────────────────────────────────────

export async function registerToken(input: RegisterTokenInput): Promise<void> {
  await notificationsRepository.upsertFcmToken(input.userId, input.fcmToken, input.deviceType);
}

export async function unregisterToken(token: string): Promise<void> {
  await notificationsRepository.deleteFcmToken(token);
}

export async function unregisterAllTokens(userId: string): Promise<void> {
  await notificationsRepository.deleteUserFcmTokens(userId);
}

// ── Notifications CRUD ────────────────────────────────────────────────────────

export async function getNotifications(userId: string, query: GetNotificationsQuery) {
  const { page, limit } = query;
  const { items, total } = await notificationsRepository.findUserNotifications(userId, page, limit);
  return {
    notifications: items,
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
}

export async function markRead(notificationId: string, userId: string): Promise<void> {
  await notificationsRepository.markNotificationRead(notificationId, userId);
}

export async function markAllRead(userId: string): Promise<void> {
  await notificationsRepository.markAllNotificationsRead(userId);
}

export async function deleteNotification(notificationId: string, userId: string): Promise<void> {
  await notificationsRepository.deleteNotification(notificationId, userId);
}

export async function deleteAllNotifications(userId: string): Promise<void> {
  await notificationsRepository.deleteAllNotifications(userId);
}

// ── Push Notification Senders ─────────────────────────────────────────────────
// These are called fire-and-forget from other service modules.

/**
 * Notify the users involved in a newly-added expense (its participants plus
 * whoever paid), excluding the actor who created it — not the whole group.
 */
export async function notifyGroupExpenseAdded(opts: {
  groupId: string;
  groupName: string;
  actorId: string;
  actorName: string;
  actorAvatar: string | null;
  expenseTitle: string;
  amount: number;
  recipientUserIds: string[];
  currency?: string;
}): Promise<void> {
  const {
    groupId,
    groupName,
    actorId,
    actorName,
    actorAvatar,
    expenseTitle,
    amount,
    recipientUserIds,
  } = opts;
  const currency = opts.currency ?? '₹';
  const title = groupName;
  const body = `${actorName} added ${currency}${amount} for "${expenseTitle}"`;

  const recipientIds = recipientUserIds.filter((id) => id !== actorId);

  // Persist in-app notifications for each recipient
  await notificationsRepository.createNotifications(
    recipientIds.map((userId) => ({
      userId,
      type: 'GROUP_EXPENSE_ADDED' as const,
      title,
      body,
      groupId,
      actorName,
      actorAvatar: actorAvatar ?? undefined,
      data: { type: 'GROUP_EXPENSE_ADDED', groupId },
    }))
  );

  await sendPushNotificationsToUsers(recipientIds, title, body, {
    type: 'GROUP_EXPENSE_ADDED',
    groupId,
    actorName,
  });
}

/**
 * Notify the payee that a settlement was received.
 */
export async function notifySettlementReceived(opts: {
  groupId: string;
  groupName: string;
  payerId: string;
  payerName: string;
  payerAvatar: string | null;
  payeeId: string;
  amount: number;
  currency?: string;
}): Promise<void> {
  const { groupId, groupName, payerId, payerName, payerAvatar, payeeId, amount } = opts;
  const currency = opts.currency ?? '₹';
  const title = groupName;
  const body = `${payerName} settled ${currency}${amount} with you`;

  await notificationsRepository.createNotification({
    userId: payeeId,
    type: 'SETTLEMENT_RECEIVED',
    title,
    body,
    groupId,
    actorName: payerName,
    actorAvatar: payerAvatar ?? undefined,
    data: { type: 'SETTLEMENT_RECEIVED', groupId, payerId },
  });

  await sendPushNotificationsToUsers([payeeId], title, body, {
    type: 'SETTLEMENT_RECEIVED',
    groupId,
    actorName: payerName,
  });
}

/**
 * Notify a user that they were added to a group.
 */
export async function notifyAddedToGroup(opts: {
  userId: string;
  groupId: string;
  groupName: string;
  addedByName: string;
}): Promise<void> {
  const { userId, groupId, groupName, addedByName } = opts;
  const title = 'Added to a group';
  const body = `${addedByName} added you to "${groupName}"`;

  await notificationsRepository.createNotification({
    userId,
    type: 'ADDED_TO_GROUP',
    title,
    body,
    groupId,
    actorName: addedByName,
    data: { type: 'ADDED_TO_GROUP', groupId },
  });

  await sendPushNotificationsToUsers([userId], title, body, {
    type: 'ADDED_TO_GROUP',
    groupId,
    actorName: addedByName,
  });
}

/**
 * Notify the invite creator that someone joined their group via their invite.
 */
export async function notifyMemberJoined(opts: {
  inviterId: string;
  groupId: string;
  groupName: string;
  joinerName: string;
}): Promise<void> {
  const { inviterId, groupId, groupName, joinerName } = opts;
  const title = 'New member joined';
  const body = `${joinerName} joined "${groupName}" via your invite`;

  await notificationsRepository.createNotification({
    userId: inviterId,
    type: 'GROUP_ACTIVITY',
    title,
    body,
    groupId,
    actorName: joinerName,
    data: { type: 'GROUP_ACTIVITY', groupId },
  });

  await sendPushNotificationsToUsers([inviterId], title, body, {
    type: 'GROUP_ACTIVITY',
    groupId,
    actorName: joinerName,
  });
}

/**
 * Notify group members before a group is deleted.
 */
export async function notifyGroupDeleted(opts: {
  groupId: string;
  groupName: string;
  actorId: string;
  actorName: string;
  recipientUserIds: string[];
}): Promise<void> {
  const { groupId, groupName, actorId, actorName, recipientUserIds } = opts;
  const title = 'Group Deleted';
  const body = `${actorName} deleted group "${groupName}"`;

  const recipientIds = recipientUserIds.filter((id) => id !== actorId);
  if (recipientIds.length === 0) return;

  await notificationsRepository.createNotifications(
    recipientIds.map((userId) => ({
      userId,
      type: 'GROUP_ACTIVITY' as const,
      title,
      body,
      groupId,
      actorName,
      data: { type: 'GROUP_DELETED', groupId },
    }))
  );

  await sendPushNotificationsToUsers(recipientIds, title, body, {
    type: 'GROUP_DELETED',
    groupId,
    actorName,
  });
}

/**
 * Notify group members when an expense is deleted.
 */
export async function notifyGroupExpenseDeleted(opts: {
  groupId: string;
  groupName: string;
  actorId: string;
  actorName: string;
  actorAvatar: string | null;
  expenseTitle: string;
  amount: number;
  recipientUserIds: string[];
  currency?: string;
}): Promise<void> {
  const {
    groupId,
    groupName,
    actorId,
    actorName,
    actorAvatar,
    expenseTitle,
    amount,
    recipientUserIds,
  } = opts;
  const currency = opts.currency ?? '₹';
  const title = groupName;
  const body = `${actorName} deleted ${currency}${amount} for "${expenseTitle}"`;

  const recipientIds = recipientUserIds.filter((id) => id !== actorId);
  if (recipientIds.length === 0) return;

  await notificationsRepository.createNotifications(
    recipientIds.map((userId) => ({
      userId,
      type: 'GROUP_ACTIVITY' as const,
      title,
      body,
      groupId,
      actorName,
      actorAvatar: actorAvatar ?? undefined,
      data: { type: 'GROUP_ACTIVITY', groupId },
    }))
  );

  await sendPushNotificationsToUsers(recipientIds, title, body, {
    type: 'GROUP_ACTIVITY',
    groupId,
    actorName,
  });
}

export async function notifyPaymentReminder(opts: {
  groupId: string;
  groupName: string;
  senderId: string;
  senderName: string;
  senderAvatar: string | null;
  recipientId: string;
}): Promise<void> {
  const { groupId, groupName, senderId, senderName, senderAvatar, recipientId } = opts;
  const title = groupName;
  const body = `${senderName} reminded you to settle your balance.`;
  await notificationsRepository.createNotification({
    userId: recipientId,
    type: 'PAYMENT_REMINDER',
    title,
    body,
    groupId,
    actorName: senderName,
    actorAvatar: senderAvatar ?? undefined,
    data: { type: 'PAYMENT_REMINDER', groupId, senderId },
  });

  await sendPushNotificationsToUsers([recipientId], title, body, {
    type: 'PAYMENT_REMINDER',
    groupId,
    senderId,
  });
}

/**
 * Notify group members when an expense is updated.
 */
export async function notifyGroupExpenseUpdated(opts: {
  groupId: string;
  groupName: string;
  actorId: string;
  actorName: string;
  actorAvatar: string | null;
  expenseTitle: string;
  amount: number;
  recipientUserIds: string[];
  currency?: string;
  changes?: string[];
}): Promise<void> {
  const {
    groupId,
    groupName,
    actorId,
    actorName,
    actorAvatar,
    expenseTitle,
    amount,
    recipientUserIds,
    changes,
  } = opts;
  const currency = opts.currency ?? '₹';
  const title = groupName;
  const changeDetail = changes && changes.length > 0 ? ` (${changes.join(', ')})` : '';
  const body = `${actorName} edited "${expenseTitle}" (${currency}${amount})${changeDetail}`;

  const recipientIds = recipientUserIds.filter((id) => id !== actorId);
  if (recipientIds.length === 0) return;

  await notificationsRepository.createNotifications(
    recipientIds.map((userId) => ({
      userId,
      type: 'GROUP_ACTIVITY' as const,
      title,
      body,
      groupId,
      actorName,
      actorAvatar: actorAvatar ?? undefined,
      data: { type: 'GROUP_ACTIVITY', groupId },
    }))
  );

  await sendPushNotificationsToUsers(recipientIds, title, body, {
    type: 'GROUP_ACTIVITY',
    groupId,
    actorName,
  });
}
