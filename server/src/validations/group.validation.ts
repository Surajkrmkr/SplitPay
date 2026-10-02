import { z } from 'zod';

export const createGroupSchema = z.object({
  name: z.string().min(1, 'Group name is required').max(100, 'Group name too long'),
  description: z.string().max(500, 'Description too long').optional(),
  avatar: z
    .union([
      z.string().url('Avatar must be a valid URL'),
      z.string().regex(/^app-icon:[a-z]+$/, 'Invalid group icon'),
    ])
    .optional(),
  memberIds: z.array(z.string().uuid('Invalid user ID')).max(100).default([]),
});

export const addMemberSchema = z.object({
  userId: z.string().uuid('Invalid user ID format'),
});

export const updateGroupSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().max(500).optional(),
  avatar: z.union([z.string().url(), z.string().regex(/^app-icon:[a-z]+$/)]).optional(),
});

export const updateMemberRoleSchema = z.object({
  role: z.enum(['ADMIN', 'MEMBER']),
});

export const reorderGroupsSchema = z.object({
  groupIds: z
    .array(z.string().uuid('Invalid group ID'))
    .refine((ids) => new Set(ids).size === ids.length, 'Group IDs must be unique'),
});

export const paymentReminderSchema = z.object({
  recipientId: z.string().uuid('Invalid recipient ID'),
});

export type CreateGroupInput = z.infer<typeof createGroupSchema>;
export type AddMemberInput = z.infer<typeof addMemberSchema>;
export type UpdateGroupInput = z.infer<typeof updateGroupSchema>;
export type UpdateMemberRoleInput = z.infer<typeof updateMemberRoleSchema>;
export type ReorderGroupsInput = z.infer<typeof reorderGroupsSchema>;
export type PaymentReminderInput = z.infer<typeof paymentReminderSchema>;
