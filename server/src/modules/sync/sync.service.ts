import { PersonalTxType, TxRecurrenceType } from '@prisma/client';
import * as txRepo from '../transactions/transactions.repository';
import * as catRepo from '../categories/categories.repository';
import { SyncPushInput, SyncPullQuery } from '../../validations/sync.validation';

export interface SyncPushResult {
  transactions: { localId: string; serverId: string; action: string; success: boolean; error?: string }[];
  categories: { localId: string; serverId: string; action: string; success: boolean; error?: string }[];
  syncedAt: string;
}

export interface SyncPullResult {
  transactions: object[];
  categories: object[];
  serverTime: string;
}

export async function pushChanges(userId: string, input: SyncPushInput): Promise<SyncPushResult> {
  const txResults: SyncPushResult['transactions'] = [];
  const catResults: SyncPushResult['categories'] = [];

  // Process transactions
  for (const pending of input.transactions) {
    try {
      if (pending.action === 'delete') {
        if (pending.serverId) {
          await txRepo.softDeleteTransaction(pending.serverId, userId);
        } else {
          await txRepo.softDeleteByLocalId(userId, pending.localId);
        }
        txResults.push({ localId: pending.localId, serverId: pending.serverId ?? '', action: 'delete', success: true });
        continue;
      }

      if (!pending.amount || !pending.type || !pending.categoryKey || !pending.date) {
        txResults.push({ localId: pending.localId, serverId: pending.serverId ?? '', action: pending.action, success: false, error: 'Missing required fields' });
        continue;
      }

      const data = {
        amount: pending.amount,
        type: pending.type as PersonalTxType,
        categoryKey: pending.categoryKey,
        customCategoryId: pending.customCategoryId ?? null,
        appIcon: pending.appIcon ?? null,
        note: pending.note ?? null,
        date: new Date(pending.date),
        recurrence: (pending.recurrence ?? 'NONE') as TxRecurrenceType,
        groupId: pending.groupId ?? null,
        deviceId: pending.deviceId ?? null,
      };

      const tx = await txRepo.upsertByLocalId(userId, pending.localId, data);
      txResults.push({ localId: pending.localId, serverId: tx.id, action: pending.action, success: true });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      txResults.push({ localId: pending.localId, serverId: pending.serverId ?? '', action: pending.action, success: false, error: message });
    }
  }

  // Process categories
  for (const pending of input.categories) {
    try {
      if (pending.action === 'delete') {
        if (pending.serverId) {
          await catRepo.softDelete(pending.serverId);
        } else {
          await catRepo.softDeleteByLocalId(userId, pending.localId);
        }
        catResults.push({ localId: pending.localId, serverId: pending.serverId ?? '', action: 'delete', success: true });
        continue;
      }

      if (!pending.label || pending.colorValue === undefined || pending.iconCodePoint === undefined) {
        catResults.push({ localId: pending.localId, serverId: pending.serverId ?? '', action: pending.action, success: false, error: 'Missing required fields' });
        continue;
      }

      const cat = await catRepo.upsertByLocalId(userId, pending.localId, {
        label: pending.label,
        colorValue: pending.colorValue,
        iconCodePoint: pending.iconCodePoint,
      });
      catResults.push({ localId: pending.localId, serverId: cat.id, action: pending.action, success: true });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      catResults.push({ localId: pending.localId, serverId: pending.serverId ?? '', action: pending.action, success: false, error: message });
    }
  }

  return {
    transactions: txResults,
    categories: catResults,
    syncedAt: new Date().toISOString(),
  };
}

export async function pullChanges(userId: string, query: SyncPullQuery): Promise<SyncPullResult> {
  const since = query.since ? new Date(query.since) : new Date(0);

  const [transactions, categories] = await Promise.all([
    txRepo.findChangedSince(userId, since),
    catRepo.findChangedSince(userId, since),
  ]);

  return {
    transactions,
    categories,
    serverTime: new Date().toISOString(),
  };
}
