import * as notificationsRepository from './notifications.repository';
import { sendPushNotification } from '../../utils/fcm';
import { RegisterTokenInput, GetNotificationsQuery } from '../../validations/notification.validation';
import { NotFoundError } from '../../utils/app-error';

// ── Token Management ──────────────────────────────────────────────────────────

export async function registerToken(input: RegisterTokenInput): Promise<void> {
  await notificationsRepository.upsertFcmToken(
    input.userId,
    input.fcmToken,
    input.deviceType
  );
}

export async function unregisterToken(token: string): Promise<void> {
  await notificationsRepository.deleteFcmToken(token);
}

export async function unregisterAllTokens(userId: string): Promise<void> {
  await notificationsRepository.deleteUserFcmTokens(userId);
}

// ── Notifications CRUD ────────────────────────────────────────────────────────

export async function getNotifications(
  userId: string,
  query: GetNotificationsQuery
) {
  const { page, limit } = query;
  const { items, total } = await notificationsRepository.findUserNotifications(
    userId,
    page,
    limit
  );
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

export async function markRead(
  notificationId: string,
  userId: string
): Promise<void> {
  await notificationsRepository.markNotificationRead(notificationId, userId);
}

export async function markAllRead(userId: string): Promise<void> {
  await notificationsRepository.markAllNotificationsRead(userId);
}

export async function deleteNotification(
  notificationId: string,
  userId: string
): Promise<void> {
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
  const { groupId, groupName, actorId, actorName, actorAvatar, expenseTitle, amount, recipientUserIds } = opts;
  const currency = opts.currency ?? '₹';
  const title = groupName;
  const body = `${actorName} added ${currency}${amount} for "${expenseTitle}"`;

  const recipientIds = recipientUserIds.filter((id) => id !== actorId);
  const tokens = await notificationsRepository.getUserFcmTokensFor(recipientIds);

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

  // Fire FCM (best-effort, non-blocking)
  if (tokens.length > 0) {
    sendPushNotification({
      tokens,
      title,
      body,
      data: { type: 'GROUP_EXPENSE_ADDED', groupId, actorName },
    }).catch(() => {});
  }
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

  const tokens = await notificationsRepository.getUserFcmTokens(payeeId);

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

  if (tokens.length > 0) {
    sendPushNotification({
      tokens,
      title,
      body,
      data: { type: 'SETTLEMENT_RECEIVED', groupId, actorName: payerName },
    }).catch(() => {});
  }
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

  const tokens = await notificationsRepository.getUserFcmTokens(userId);

  await notificationsRepository.createNotification({
    userId,
    type: 'ADDED_TO_GROUP',
    title,
    body,
    groupId,
    actorName: addedByName,
    data: { type: 'ADDED_TO_GROUP', groupId },
  });

  if (tokens.length > 0) {
    sendPushNotification({
      tokens,
      title,
      body,
      data: { type: 'ADDED_TO_GROUP', groupId, actorName: addedByName },
    }).catch(() => {});
  }
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

  const tokens = await notificationsRepository.getUserFcmTokens(inviterId);

  await notificationsRepository.createNotification({
    userId: inviterId,
    type: 'GROUP_ACTIVITY',
    title,
    body,
    groupId,
    actorName: joinerName,
    data: { type: 'GROUP_ACTIVITY', groupId },
  });

  if (tokens.length > 0) {
    sendPushNotification({
      tokens,
      title,
      body,
      data: { type: 'GROUP_ACTIVITY', groupId, actorName: joinerName },
    }).catch(() => {});
  }
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

  const tokens = await notificationsRepository.getUserFcmTokensFor(recipientIds);

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

  if (tokens.length > 0) {
    await sendPushNotification({
      tokens,
      title,
      body,
      data: { type: 'GROUP_DELETED', groupId, actorName },
    }).catch(() => {});
  }
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
  const { groupId, groupName, actorId, actorName, actorAvatar, expenseTitle, amount, recipientUserIds } = opts;
  const currency = opts.currency ?? '₹';
  const title = groupName;
  const body = `${actorName} deleted ${currency}${amount} for "${expenseTitle}"`;

  const recipientIds = recipientUserIds.filter((id) => id !== actorId);
  if (recipientIds.length === 0) return;

  const tokens = await notificationsRepository.getUserFcmTokensFor(recipientIds);

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

  if (tokens.length > 0) {
    sendPushNotification({
      tokens,
      title,
      body,
      data: { type: 'GROUP_ACTIVITY', groupId, actorName },
    }).catch(() => {});
  }
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
  const { groupId, groupName, actorId, actorName, actorAvatar, expenseTitle, amount, recipientUserIds, changes } = opts;
  const currency = opts.currency ?? '₹';
  const title = groupName;
  const changeDetail = changes && changes.length > 0 ? ` (${changes.join(', ')})` : '';
  const body = `${actorName} edited "${expenseTitle}" (${currency}${amount})${changeDetail}`;

  const recipientIds = recipientUserIds.filter((id) => id !== actorId);
  if (recipientIds.length === 0) return;

  const tokens = await notificationsRepository.getUserFcmTokensFor(recipientIds);

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

  if (tokens.length > 0) {
    sendPushNotification({
      tokens,
      title,
      body,
      data: { type: 'GROUP_ACTIVITY', groupId, actorName },
    }).catch(() => {});
  }
}

