import { z } from 'zod';

const pendingTransactionSchema = z.object({
  localId: z.string().uuid(),
  serverId: z.string().uuid().optional().nullable(),
  action: z.enum(['create', 'update', 'delete']),
  amount: z.number().positive().optional(),
  type: z.enum(['INCOME', 'EXPENSE', 'TRANSFER']).optional(),
  categoryKey: z.string().min(1).optional(),
  customCategoryId: z.string().uuid().optional().nullable(),
  appIcon: z.string().optional().nullable(),
  note: z.string().max(1000).optional().nullable(),
  date: z.string().datetime().optional(),
  recurrence: z.enum(['NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']).optional(),
  groupId: z.string().uuid().optional().nullable(),
  deviceId: z.string().max(200).optional().nullable(),
  updatedAt: z.string().datetime(),
});

const pendingCategorySchema = z.object({
  localId: z.string().uuid(),
  serverId: z.string().uuid().optional().nullable(),
  action: z.enum(['create', 'update', 'delete']),
  label: z.string().min(1).max(100).optional(),
  colorValue: z.number().int().optional(),
  iconCodePoint: z.number().int().positive().optional(),
  updatedAt: z.string().datetime(),
});

export const syncPushSchema = z.object({
  transactions: z.array(pendingTransactionSchema).max(500).default([]),
  categories: z.array(pendingCategorySchema).max(200).default([]),
});

export const syncPullSchema = z.object({
  since: z.string().datetime().optional(),
});

export type SyncPushInput = z.infer<typeof syncPushSchema>;
export type SyncPullQuery = z.infer<typeof syncPullSchema>;
export type PendingTransaction = z.infer<typeof pendingTransactionSchema>;
export type PendingCategory = z.infer<typeof pendingCategorySchema>;
