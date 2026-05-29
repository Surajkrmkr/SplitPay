import { z } from 'zod';

const participantSchema = z.object({
  userId: z.string().uuid('Invalid user ID'),
  share: z.number().min(0, 'Share cannot be negative').optional(),
  percentage: z.number().min(0, 'Percentage cannot be negative').max(100).optional(),
});

export const createExpenseSchema = z
  .object({
    groupId: z.string().uuid('Invalid group ID'),
    title: z.string().min(1, 'Title is required').max(200, 'Title too long'),
    amount: z.number().positive('Amount must be positive'),
    paidById: z.string().uuid('Invalid paidBy user ID'),
    splitType: z.enum(['EQUAL', 'PERCENTAGE', 'EXACT']),
    notes: z.string().max(1000, 'Notes too long').optional(),
    date: z.string().datetime().optional(),
    participants: z
      .array(participantSchema)
      .min(1, 'At least one participant is required'),
  })
  .superRefine((data, ctx) => {
    if (data.splitType === 'PERCENTAGE') {
      // Each participant must have a percentage
      const totalPercentage = data.participants.reduce((sum, p) => {
        if (p.percentage === undefined) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: 'Each participant must have a percentage when splitType is PERCENTAGE',
            path: ['participants'],
          });
          return sum;
        }
        return sum + p.percentage;
      }, 0);

      if (Math.abs(totalPercentage - 100) > 0.01) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: `Percentages must sum to 100 (got ${totalPercentage})`,
          path: ['participants'],
        });
      }
    }

    if (data.splitType === 'EXACT') {
      // Each participant must have a share
      const totalShares = data.participants.reduce((sum, p) => {
        if (p.share === undefined) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: 'Each participant must have a share amount when splitType is EXACT',
            path: ['participants'],
          });
          return sum;
        }
        return sum + p.share;
      }, 0);

      if (Math.abs(totalShares - data.amount) > 0.01) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: `Exact shares must sum to the total amount ${data.amount} (got ${totalShares})`,
          path: ['participants'],
        });
      }
    }
  });

export const updateExpenseSchema = z
  .object({
    title: z.string().min(1).max(200).optional(),
    amount: z.number().positive().optional(),
    paidById: z.string().uuid().optional(),
    splitType: z.enum(['EQUAL', 'PERCENTAGE', 'EXACT']).optional(),
    notes: z.string().max(1000).optional().nullable(),
    date: z.string().datetime().optional(),
    participants: z.array(participantSchema).min(1).optional(),
  })
  .superRefine((data, ctx) => {
    if (!data.participants || !data.amount) return;
    if (data.splitType === 'PERCENTAGE') {
      const total = data.participants.reduce((s, p) => s + (p.percentage ?? 0), 0);
      if (Math.abs(total - 100) > 0.01) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: `Percentages must sum to 100`, path: ['participants'] });
      }
    }
    if (data.splitType === 'EXACT') {
      const total = data.participants.reduce((s, p) => s + (p.share ?? 0), 0);
      if (Math.abs(total - data.amount) > 0.01) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: `Shares must sum to amount`, path: ['participants'] });
      }
    }
  });

export type CreateExpenseInput = z.infer<typeof createExpenseSchema>;
export type UpdateExpenseInput = z.infer<typeof updateExpenseSchema>;
