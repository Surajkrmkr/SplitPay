import { z } from 'zod';

export const createBudgetSchema = z.object({
  title: z.string().min(1, 'Title is required').max(100),
  amount: z.number().positive('Amount must be positive'),
  categoryIds: z.array(z.string()).default([]),
  period: z.enum(['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']),
  startDate: z.string().datetime(),
  colorValue: z.number().int(),
  iconCodePoint: z.number().int().positive(),
  alertThreshold: z.number().min(0).max(1).default(0.8),
});

export const updateBudgetSchema = z.object({
  title: z.string().min(1).max(100).optional(),
  amount: z.number().positive().optional(),
  categoryIds: z.array(z.string()).optional(),
  period: z.enum(['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']).optional(),
  startDate: z.string().datetime().optional(),
  colorValue: z.number().int().optional(),
  iconCodePoint: z.number().int().positive().optional(),
  isArchived: z.boolean().optional(),
  alertThreshold: z.number().min(0).max(1).optional(),
});

export const reorderBudgetsSchema = z.object({
  budgetIds: z
    .array(z.string().uuid('Invalid budget ID'))
    .refine((ids) => new Set(ids).size === ids.length, 'Budget IDs must be unique'),
});

export type CreateBudgetInput = z.infer<typeof createBudgetSchema>;
export type UpdateBudgetInput = z.infer<typeof updateBudgetSchema>;
export type ReorderBudgetsInput = z.infer<typeof reorderBudgetsSchema>;
