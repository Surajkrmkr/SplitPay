import { ForbiddenError, BadRequestError } from '../../utils/app-error';
import * as settlementsRepository from './settlements.repository';
import { SettlementWithUsers } from './settlements.repository';
import * as groupsRepository from '../groups/groups.repository';
import * as expensesRepository from '../expenses/expenses.repository';
import * as activityRepository from '../activity/activity.repository';
import * as notificationsService from '../notifications/notifications.service';
import { CreateSettlementInput } from '../../validations/settlement.validation';
import { calculateNetBalances, simplifyDebts } from '../../utils/balance';

export async function createSettlement(
  userId: string,
  input: CreateSettlementInput
): Promise<SettlementWithUsers> {
  const { groupId, settledAt, ...rest } = input;

  if (input.payeeId === userId) {
    throw new ForbiddenError('Payer and payee cannot be the same person');
  }

  // Verify user is a group member
  const isMember = await groupsRepository.isMember(groupId, userId);
  if (!isMember) {
    throw new ForbiddenError('You are not a member of this group');
  }

  // A settlement should never exceed what the payer currently owes the
  // payee — otherwise it silently flips the debt direction instead of
  // erroring out.
  const expenses = await expensesRepository.findGroupExpensesForBalance(groupId);
  const existingSettlements = await settlementsRepository.findGroupSettlementsForBalance(groupId);

  const expenseData = expenses.map((e) => ({
    id: e.id,
    amount: Number(e.amount),
    paidById: e.paidById,
    participants: e.participants.map((p) => ({ userId: p.userId, share: Number(p.share) })),
  }));
  const settlementData = existingSettlements.map((s) => ({
    payerId: s.payerId,
    payeeId: s.payeeId,
    amount: Number(s.amount),
  }));

  const rawBalances = calculateNetBalances(expenseData, settlementData);
  const simplified = simplifyDebts(rawBalances);
  const owed =
    simplified.find((b) => b.fromUserId === userId && b.toUserId === input.payeeId)?.amount ?? 0;

  if (input.amount - owed > 0.01) {
    throw new BadRequestError(
      `Settlement amount (${input.amount}) exceeds the outstanding balance (${owed})`
    );
  }

  const settlement = await settlementsRepository.createSettlement({
    ...rest,
    groupId,
    payerId: userId,
    settledAt: settledAt ? new Date(settledAt) : undefined,
  });

  // Log SETTLEMENT_COMPLETED activity
  await activityRepository.createActivity({
    groupId,
    userId,
    type: 'SETTLEMENT_COMPLETED',
    settlementId: settlement.id,
    metadata: {
      payerId: settlement.payerId,
      payeeId: settlement.payeeId,
      amount: Number(settlement.amount),
      paymentMethod: settlement.paymentMethod,
    },
  });

  // Notify payee (fire-and-forget)
  const group = await groupsRepository.findGroupById(groupId);
  if (group) {
    const payer = group.members.find((m) => m.userId === userId)?.user;
    notificationsService
      .notifySettlementReceived({
        groupId,
        groupName: group.name,
        payerId: userId,
        payerName: payer?.name ?? 'Someone',
        payerAvatar: payer?.avatar ?? null,
        payeeId: input.payeeId,
        amount: Number(settlement.amount),
      })
      .catch(() => {});
  }

  return settlement;
}

export async function getGroupSettlements(
  groupId: string,
  userId: string
): Promise<SettlementWithUsers[]> {
  // Verify membership
  const isMember = await groupsRepository.isMember(groupId, userId);
  if (!isMember) {
    throw new ForbiddenError('You are not a member of this group');
  }

  return settlementsRepository.findGroupSettlements(groupId);
}
