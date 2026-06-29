import { z } from 'zod';

export const createTransactionSchema = z.object({
  amount: z.number().positive('Amount must be positive'),
  type: z.enum(['INCOME', 'EXPENSE', 'TRANSFER']),
  categoryKey: z.string().min(1, 'Category key is required'),
  customCategoryId: z.string().uuid().optional().nullable(),
  appIcon: z.string().optional().nullable(),
  note: z.string().max(1000).optional().nullable(),
  date: z.string().datetime(),
  recurrence: z.enum(['NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']).default('NONE'),
  groupId: z.string().uuid().optional().nullable(),
  deviceId: z.string().max(200).optional().nullable(),
});

export const updateTransactionSchema = z.object({
  amount: z.number().positive().optional(),
  type: z.enum(['INCOME', 'EXPENSE', 'TRANSFER']).optional(),
  categoryKey: z.string().min(1).optional(),
  customCategoryId: z.string().uuid().optional().nullable(),
  appIcon: z.string().optional().nullable(),
  note: z.string().max(1000).optional().nullable(),
  date: z.string().datetime().optional(),
  recurrence: z.enum(['NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']).optional(),
});

export const listTransactionsSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  type: z.enum(['INCOME', 'EXPENSE', 'TRANSFER']).optional(),
  categoryKey: z.string().optional(),
  search: z.string().max(200).optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
});

export type CreateTransactionInput = z.infer<typeof createTransactionSchema>;
export type UpdateTransactionInput = z.infer<typeof updateTransactionSchema>;
export type ListTransactionsQuery = z.infer<typeof listTransactionsSchema>;
