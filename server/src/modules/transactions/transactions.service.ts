import { PersonalTxType, TxRecurrenceType } from '@prisma/client';
import { NotFoundError, ForbiddenError } from '../../utils/app-error';
import * as repo from './transactions.repository';
import { CreateTransactionInput, UpdateTransactionInput, ListTransactionsQuery } from '../../validations/transaction.validation';

export async function createTransaction(userId: string, input: CreateTransactionInput) {
  const data = {
    amount: input.amount,
    type: input.type as PersonalTxType,
    categoryKey: input.categoryKey,
    customCategoryId: input.customCategoryId ?? null,
    appIcon: input.appIcon ?? null,
    note: input.note ?? null,
    date: new Date(input.date),
    recurrence: (input.recurrence ?? 'NONE') as TxRecurrenceType,
    groupId: input.groupId ?? null,
    deviceId: input.deviceId ?? null,
  };

  return repo.upsertByLocalId(userId, input.localId, data);
}

export async function getTransactions(userId: string, query: ListTransactionsQuery) {
  return repo.findTransactions(userId, {
    ...query,
    type: query.type as PersonalTxType | undefined,
    startDate: query.startDate ? new Date(query.startDate) : undefined,
    endDate: query.endDate ? new Date(query.endDate) : undefined,
  });
}

export async function getTransactionById(userId: string, id: string) {
  const tx = await repo.findTransactionById(id, userId);
  if (!tx) throw new NotFoundError('Transaction not found');
  return tx;
}

export async function updateTransaction(userId: string, id: string, input: UpdateTransactionInput) {
  const tx = await repo.findTransactionById(id, userId);
  if (!tx) throw new NotFoundError('Transaction not found');
  if (tx.userId !== userId) throw new ForbiddenError('Not your transaction');

  return repo.updateTransaction(id, userId, {
    ...(input.amount !== undefined ? { amount: input.amount } : {}),
    ...(input.type ? { type: input.type as PersonalTxType } : {}),
    ...(input.categoryKey ? { categoryKey: input.categoryKey } : {}),
    ...(input.customCategoryId !== undefined ? { customCategoryId: input.customCategoryId } : {}),
    ...(input.appIcon !== undefined ? { appIcon: input.appIcon } : {}),
    ...(input.note !== undefined ? { note: input.note } : {}),
    ...(input.date ? { date: new Date(input.date) } : {}),
    ...(input.recurrence ? { recurrence: input.recurrence as TxRecurrenceType } : {}),
  });
}

export async function deleteTransaction(userId: string, id: string) {
  const tx = await repo.findTransactionById(id, userId);
  if (!tx) throw new NotFoundError('Transaction not found');
  if (tx.userId !== userId) throw new ForbiddenError('Not your transaction');

  await repo.softDeleteTransaction(id, userId);
}
