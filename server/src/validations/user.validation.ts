import { z } from 'zod';

export const searchQuerySchema = z.object({
  q: z.string().min(1, 'Search query must be at least 1 character').max(100, 'Query too long'),
});

export type SearchQueryInput = z.infer<typeof searchQuerySchema>;

export const updateProfileSchema = z
  .object({
    firstName: z
      .string()
      .trim()
      .min(1, 'First name cannot be empty')
      .max(50, 'First name too long')
      .optional(),
    lastName: z.string().trim().max(50, 'Last name too long').optional(),
    name: z.string().trim().min(1, 'Name cannot be empty').max(100, 'Name too long').optional(),
  })
  .refine(
    (data) =>
      data.firstName !== undefined || data.lastName !== undefined || data.name !== undefined,
    {
      message: 'At least one name field must be provided',
    }
  );

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
