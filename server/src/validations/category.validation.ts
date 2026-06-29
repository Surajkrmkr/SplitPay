import { z } from 'zod';

export const createCategorySchema = z.object({
  label: z.string().min(1, 'Label is required').max(100),
  colorValue: z.number().int(),
  iconCodePoint: z.number().int().positive(),
});

export const updateCategorySchema = z.object({
  label: z.string().min(1).max(100).optional(),
  colorValue: z.number().int().optional(),
  iconCodePoint: z.number().int().positive().optional(),
});

export type CreateCategoryInput = z.infer<typeof createCategorySchema>;
export type UpdateCategoryInput = z.infer<typeof updateCategorySchema>;
