import { z } from 'zod';

export const registerTokenSchema = z.object({
  userId: z.string().uuid('Invalid user ID'),
  fcmToken: z.string().min(1, 'FCM token is required'),
  deviceType: z.enum(['ios', 'android']),
});

export const getNotificationsSchema = z.object({
  page: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v, 10) : 1))
    .pipe(z.number().int().min(1)),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v, 10) : 30))
    .pipe(z.number().int().min(1).max(100)),
});

export type RegisterTokenInput = z.infer<typeof registerTokenSchema>;
export type GetNotificationsQuery = z.infer<typeof getNotificationsSchema>;
