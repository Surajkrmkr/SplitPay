import { z } from 'zod';

export const createGroupSchema = z.object({
  name: z.string().min(1, 'Group name is required').max(100, 'Group name too long'),
  description: z.string().max(500, 'Description too long').optional(),
  avatar: z.string().url('Avatar must be a valid URL').optional(),
});

export const addMemberSchema = z.object({
  userId: z.string().uuid('Invalid user ID format'),
});

export const updateGroupSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().max(500).optional(),
  avatar: z.string().url().optional(),
});

export const updateMemberRoleSchema = z.object({
  role: z.enum(['ADMIN', 'MEMBER']),
});

export type CreateGroupInput = z.infer<typeof createGroupSchema>;
export type AddMemberInput = z.infer<typeof addMemberSchema>;
export type UpdateGroupInput = z.infer<typeof updateGroupSchema>;
export type UpdateMemberRoleInput = z.infer<typeof updateMemberRoleSchema>;
