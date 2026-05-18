import { z } from 'zod';

export const createSettlementSchema = z
  .object({
    groupId: z.string().uuid('Invalid group ID'),
    payerId: z.string().uuid('Invalid payer ID'),
    payeeId: z.string().uuid('Invalid payee ID'),
    amount: z.number().positive('Amount must be positive'),
    notes: z.string().max(500, 'Notes too long').optional(),
    settledAt: z.string().datetime().optional(),
  })
  .refine((data) => data.payerId !== data.payeeId, {
    message: 'Payer and payee cannot be the same person',
    path: ['payeeId'],
  });

export type CreateSettlementInput = z.infer<typeof createSettlementSchema>;
