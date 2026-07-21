import { prisma } from '../../prisma/client';
import { PersonalTxType, TxRecurrenceType } from '@prisma/client';

export interface CreateTransactionData {
  userId: string;
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
  return prisma.transaction.create({ data });
}

export async function findTransactionById(id: string, userId: string) {
  return prisma.transaction.findFirst({
    where: { id, userId, deletedAt: null },
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

// Soft-deletes every existing (non-deleted) transaction for the user, then
// inserts the imported rows — both in one DB transaction so a mid-import
// failure never leaves the user with their old data half-wiped and no
// replacement.
export async function replaceAllTransactions(userId: string, rows: CreateTransactionData[]) {
  return prisma.$transaction(async (tx) => {
    const { count: replaced } = await tx.transaction.updateMany({
      where: { userId, deletedAt: null },
      data: { deletedAt: new Date() },
    });

    if (rows.length > 0) {
      await tx.transaction.createMany({ data: rows });
    }

    return { replaced, imported: rows.length };
  });
}
