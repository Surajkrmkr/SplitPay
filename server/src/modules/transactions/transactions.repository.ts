import { prisma } from '../../prisma/client';
import { PersonalTxType, TxRecurrenceType } from '@prisma/client';

export interface CreateTransactionData {
  userId: string;
  localId: string;
  amount: number;
  type: PersonalTxType;
  categoryKey: string;
  customCategoryId?: string | null;
  appIcon?: string | null;
  note?: string | null;
  date: Date;
  recurrence: TxRecurrenceType;
  groupId?: string | null;
  deviceId?: string | null;
}

export interface UpdateTransactionData {
  amount?: number;
  type?: PersonalTxType;
  categoryKey?: string;
  customCategoryId?: string | null;
  appIcon?: string | null;
  note?: string | null;
  date?: Date;
  recurrence?: TxRecurrenceType;
  deletedAt?: Date | null;
}

export interface TransactionFilters {
  type?: PersonalTxType;
  categoryKey?: string;
  search?: string;
  startDate?: Date;
  endDate?: Date;
  page: number;
  limit: number;
}

export async function createTransaction(data: CreateTransactionData) {
  return prisma.transaction.create({
    data: {
      ...data,
      amount: data.amount,
    },
  });
}

export async function upsertByLocalId(userId: string, localId: string, data: Omit<CreateTransactionData, 'userId' | 'localId'>) {
  return prisma.transaction.upsert({
    where: { userId_localId: { userId, localId } },
    create: { userId, localId, ...data },
    update: { ...data },
  });
}

export async function findTransactionById(id: string, userId: string) {
  return prisma.transaction.findFirst({
    where: { id, userId, deletedAt: null },
  });
}

export async function findTransactionByLocalId(userId: string, localId: string) {
  return prisma.transaction.findUnique({
    where: { userId_localId: { userId, localId } },
  });
}

export async function findTransactions(userId: string, filters: TransactionFilters) {
  const { type, categoryKey, search, startDate, endDate, page, limit } = filters;
  const skip = (page - 1) * limit;

  const where = {
    userId,
    deletedAt: null,
    ...(type ? { type } : {}),
    ...(categoryKey ? { categoryKey } : {}),
    ...(startDate || endDate
      ? {
          date: {
            ...(startDate ? { gte: startDate } : {}),
            ...(endDate ? { lte: endDate } : {}),
          },
        }
      : {}),
    ...(search
      ? {
          OR: [
            { note: { contains: search, mode: 'insensitive' as const } },
            { categoryKey: { contains: search, mode: 'insensitive' as const } },
          ],
        }
      : {}),
  };

  const [total, items] = await Promise.all([
    prisma.transaction.count({ where }),
    prisma.transaction.findMany({
      where,
      orderBy: { date: 'desc' },
      skip,
      take: limit,
    }),
  ]);

  return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
}

export async function updateTransaction(id: string, userId: string, data: UpdateTransactionData) {
  return prisma.transaction.update({
    where: { id },
    data: { ...data, userId },
  });
}

export async function softDeleteTransaction(id: string, userId: string) {
  return prisma.transaction.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
}

export async function softDeleteByLocalId(userId: string, localId: string) {
  const tx = await prisma.transaction.findUnique({
    where: { userId_localId: { userId, localId } },
  });
  if (!tx) return null;
  return prisma.transaction.update({
    where: { id: tx.id },
    data: { deletedAt: new Date() },
  });
}

export async function findChangedSince(userId: string, since: Date) {
  return prisma.transaction.findMany({
    where: {
      userId,
      updatedAt: { gt: since },
    },
    orderBy: { updatedAt: 'asc' },
  });
}

export async function findAllForUser(userId: string) {
  return prisma.transaction.findMany({
    where: { userId, deletedAt: null },
    orderBy: { updatedAt: 'asc' },
  });
}
