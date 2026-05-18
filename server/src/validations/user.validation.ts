import { z } from 'zod';

export const searchQuerySchema = z.object({
  q: z.string().min(1, 'Search query must be at least 1 character').max(100, 'Query too long'),
});

export type SearchQueryInput = z.infer<typeof searchQuerySchema>;
