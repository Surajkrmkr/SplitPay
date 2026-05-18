import { z } from 'zod';

export const createSettlementSchema = z.object({
  groupId: z.string().uuid('Invalid group ID'),
  payeeId: z.string().uuid('Invalid payee ID'),
  amount: z.number().positive('Amount must be positive'),
  notes: z.string().max(500, 'Notes too long').optional(),
  settledAt: z.string().datetime().optional(),
});

export type CreateSettlementInput = z.infer<typeof createSettlementSchema>;
