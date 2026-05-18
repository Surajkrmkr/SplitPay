import { ForbiddenError } from '../../utils/app-error';
import * as settlementsRepository from './settlements.repository';
import { SettlementWithUsers } from './settlements.repository';
import * as groupsRepository from '../groups/groups.repository';
import * as activityRepository from '../activity/activity.repository';
import { CreateSettlementInput } from '../../validations/settlement.validation';

export async function createSettlement(
  userId: string,
  input: CreateSettlementInput
): Promise<SettlementWithUsers> {
  const { groupId, settledAt, ...rest } = input;

  // Verify user is a group member
  const isMember = await groupsRepository.isMember(groupId, userId);
  if (!isMember) {
    throw new ForbiddenError('You are not a member of this group');
  }

  const settlement = await settlementsRepository.createSettlement({
    ...rest,
    groupId,
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
    },
  });

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
