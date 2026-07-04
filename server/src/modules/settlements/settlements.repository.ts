import { prisma } from '../../prisma/client';
import { Settlement } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

export interface CreateSettlementData {
  groupId: string;
  payerId: string;
  payeeId: string;
  amount: number;
  notes?: string;
  settledAt?: Date;
  paymentMethod?: string;
  transactionId?: string;
}

export type SettlementWithUsers = Settlement & {
  payer: { id: string; name: string; email: string; avatar: string | null };
  payee: { id: string; name: string; email: string; avatar: string | null };
};

export async function createSettlement(data: CreateSettlementData): Promise<SettlementWithUsers> {
  return prisma.settlement.create({
    data: {
      ...data,
      settledAt: data.settledAt ?? new Date(),
    },
    include: {
      payer: { select: { id: true, name: true, email: true, avatar: true } },
      payee: { select: { id: true, name: true, email: true, avatar: true } },
    },
  });
}

export async function findGroupSettlements(groupId: string): Promise<SettlementWithUsers[]> {
  return prisma.settlement.findMany({
    where: { groupId },
    include: {
      payer: { select: { id: true, name: true, email: true, avatar: true } },
      payee: { select: { id: true, name: true, email: true, avatar: true } },
    },
    orderBy: { settledAt: 'desc' },
  });
}

export async function findGroupSettlementsForBalance(groupId: string): Promise<
  { payerId: string; payeeId: string; amount: Decimal }[]
> {
  return prisma.settlement.findMany({
    where: { groupId },
    select: { payerId: true, payeeId: true, amount: true },
  });
}
