import { SplitType } from '@prisma/client';
import { ForbiddenError, BadRequestError, NotFoundError } from '../../utils/app-error';
import * as expensesRepository from './expenses.repository';
import { ExpenseWithDetails } from './expenses.repository';
import * as groupsRepository from '../groups/groups.repository';
import * as activityRepository from '../activity/activity.repository';
import * as settlementsRepository from '../settlements/settlements.repository';
import * as notificationsService from '../notifications/notifications.service';
import { CreateExpenseInput, UpdateExpenseInput } from '../../validations/expense.validation';
import {
  calculateNetBalances,
  simplifyDebts,
  SimplifiedDebt,
} from '../../utils/balance';

export async function createExpense(
  userId: string,
  input: CreateExpenseInput
): Promise<ExpenseWithDetails> {
  const { groupId, splitType, amount, participants, date, ...rest } = input;

  // Verify user is a group member
  const isMember = await groupsRepository.isMember(groupId, userId);
  if (!isMember) {
    throw new ForbiddenError('You are not a member of this group');
  }

  // Calculate participant shares based on splitType
  const calculatedParticipants = calculateShares(splitType, amount, participants);

  const expense = await expensesRepository.createExpense({
    ...rest,
    groupId,
    amount,
    splitType: splitType as SplitType,
    date: date ? new Date(date) : undefined,
    participants: calculatedParticipants,
  });

  // Log EXPENSE_ADDED activity
  await activityRepository.createActivity({
    groupId,
    userId,
    type: 'EXPENSE_ADDED',
    expenseId: expense.id,
    metadata: { title: expense.title, amount },
  });

  // Notify only the users involved in this expense (fire-and-forget)
  const group = await groupsRepository.findGroupById(groupId);
  if (group) {
    const actor = group.members.find((m) => m.userId === userId)?.user;
    const recipientUserIds = Array.from(
      new Set([expense.paidById, ...expense.participants.map((p) => p.userId)])
    );
    notificationsService
      .notifyGroupExpenseAdded({
        groupId,
        groupName: group.name,
        actorId: userId,
        actorName: actor?.name ?? 'Someone',
        actorAvatar: actor?.avatar ?? null,
        expenseTitle: expense.title,
        amount: Number(expense.amount),
        recipientUserIds,
      })
      .catch(() => {});
  }

  return expense;
}

function calculateShares(
  splitType: string,
  totalAmount: number,
  participants: { userId: string; share?: number; percentage?: number }[]
): { userId: string; share: number; percentage?: number }[] {
  const n = participants.length;

  switch (splitType) {
    case 'EQUAL': {
      const equalShare = Math.round((totalAmount / n) * 100) / 100;
      // Handle rounding remainder on first participant
      const remainder = Math.round((totalAmount - equalShare * n) * 100) / 100;
      return participants.map((p, i) => ({
        userId: p.userId,
        share: i === 0 ? equalShare + remainder : equalShare,
      }));
    }

    case 'PERCENTAGE': {
      const shares = participants.map((p) => {
        if (p.percentage === undefined) {
          throw new BadRequestError(`Missing percentage for participant ${p.userId}`);
        }
        return {
          userId: p.userId,
          share: Math.round((totalAmount * p.percentage) / 100 * 100) / 100,
          percentage: p.percentage,
        };
      });
      // Rounding each share independently can leave the sum a cent or two off
      // the total amount. Apply the remainder to the first participant so
      // shares always add up exactly, matching the EQUAL split behavior above.
      const sum = shares.reduce((s, p) => s + p.share, 0);
      const remainder = Math.round((totalAmount - sum) * 100) / 100;
      if (remainder !== 0 && shares.length > 0) {
        shares[0].share = Math.round((shares[0].share + remainder) * 100) / 100;
      }
      return shares;
    }

    case 'EXACT': {
      return participants.map((p) => {
        if (p.share === undefined) {
          throw new BadRequestError(`Missing share for participant ${p.userId}`);
        }
        return {
          userId: p.userId,
          share: p.share,
        };
      });
    }

    default:
      throw new BadRequestError(`Invalid split type: ${splitType}`);
  }
}

export async function getGroupExpenses(
  groupId: string,
  userId: string
): Promise<ExpenseWithDetails[]> {
  // Verify membership
  const isMember = await groupsRepository.isMember(groupId, userId);
  if (!isMember) {
    throw new ForbiddenError('You are not a member of this group');
  }

  return expensesRepository.findGroupExpenses(groupId);
}

export interface EnrichedBalance {
  fromUserId: string;
  fromUserName: string;
  fromUserAvatar: string | null;
  toUserId: string;
  toUserName: string;
  toUserAvatar: string | null;
  amount: number;
}

export async function updateExpense(
  expenseId: string,
  userId: string,
  input: UpdateExpenseInput
): Promise<ExpenseWithDetails> {
  const expense = await expensesRepository.findExpenseById(expenseId);
  if (!expense) throw new NotFoundError('Expense not found');

  const isMember = await groupsRepository.isMember(expense.groupId, userId);
  if (!isMember) throw new ForbiddenError('You are not a member of this group');

  const { date, participants, ...rest } = input;
  const updated = await expensesRepository.updateExpense(expenseId, {
    ...rest,
    ...(date ? { date: new Date(date) } : {}),
    ...(participants
      ? {
          participants: calculateShares(
            rest.splitType ?? expense.splitType,
            rest.amount ?? Number(expense.amount),
            participants
          ),
        }
      : {}),
  });

  await activityRepository.createActivity({
    groupId: expense.groupId,
    userId,
    type: 'EXPENSE_UPDATED',
    expenseId,
    metadata: { title: updated.title, amount: Number(updated.amount) },
  });

  return updated;
}

export async function deleteExpense(expenseId: string, userId: string): Promise<void> {
  const expense = await expensesRepository.findExpenseById(expenseId);
  if (!expense) throw new NotFoundError('Expense not found');

  const isMember = await groupsRepository.isMember(expense.groupId, userId);
  if (!isMember) throw new ForbiddenError('You are not a member of this group');

  const groupId = expense.groupId;
  const title = expense.title;
  const amount = Number(expense.amount);

  const group = await groupsRepository.findGroupById(groupId);

  await expensesRepository.deleteExpense(expenseId);

  await activityRepository.createActivity({
    groupId,
    userId,
    type: 'EXPENSE_DELETED',
    metadata: { title, expenseId },
  });

  if (group) {
    const actor = group.members.find((m) => m.userId === userId)?.user;
    const recipientUserIds = group.members.map((m) => m.userId);
    notificationsService
      .notifyGroupExpenseDeleted({
        groupId,
        groupName: group.name,
        actorId: userId,
        actorName: actor?.name ?? 'Someone',
        actorAvatar: actor?.avatar ?? null,
        expenseTitle: title,
        amount,
        recipientUserIds,
      })
      .catch(() => {});
  }
}

export interface GroupBalancesResult {
  balances: EnrichedBalance[];
  summary: {
    totalOwed: number;
    totalLent: number;
  };
}

export async function getGroupBalances(
  groupId: string,
  userId: string
): Promise<GroupBalancesResult> {
  // Verify membership
  const isMember = await groupsRepository.isMember(groupId, userId);
  if (!isMember) {
    throw new ForbiddenError('You are not a member of this group');
  }

  // Get all expenses for the group
  const expenses = await expensesRepository.findGroupExpensesForBalance(groupId);

  // Get all settlements for the group
  const settlements = await settlementsRepository.findGroupSettlementsForBalance(groupId);

  // Map to balance calculation format
  const expenseData = expenses.map((e) => ({
    id: e.id,
    amount: Number(e.amount),
    paidById: e.paidById,
    participants: e.participants.map((p) => ({
      userId: p.userId,
      share: Number(p.share),
    })),
  }));

  const settlementData = settlements.map((s) => ({
    payerId: s.payerId,
    payeeId: s.payeeId,
    amount: Number(s.amount),
  }));

  const rawBalances = calculateNetBalances(expenseData, settlementData);
  const simplifiedBalances = simplifyDebts(rawBalances);

  // Fetch group members to resolve user names/avatars
  const group = await groupsRepository.findGroupById(groupId);
  const userMap = new Map<string, { name: string; avatar: string | null }>();
  for (const member of group?.members ?? []) {
    userMap.set(member.userId, { name: member.user.name, avatar: member.user.avatar });
  }

  // Enrich balances with user names
  const enrichedBalances: EnrichedBalance[] = simplifiedBalances.map((b) => ({
    fromUserId: b.fromUserId,
    fromUserName: userMap.get(b.fromUserId)?.name ?? b.fromUserId,
    fromUserAvatar: userMap.get(b.fromUserId)?.avatar ?? null,
    toUserId: b.toUserId,
    toUserName: userMap.get(b.toUserId)?.name ?? b.toUserId,
    toUserAvatar: userMap.get(b.toUserId)?.avatar ?? null,
    amount: b.amount,
  }));

  // Calculate summary for the current user
  let totalOwed = 0;
  let totalLent = 0;

  for (const balance of enrichedBalances) {
    if (balance.fromUserId === userId) {
      totalOwed += balance.amount;
    }
    if (balance.toUserId === userId) {
      totalLent += balance.amount;
    }
  }

  return {
    balances: enrichedBalances,
    summary: {
      totalOwed: Math.round(totalOwed * 100) / 100,
      totalLent: Math.round(totalLent * 100) / 100,
    },
  };
}
