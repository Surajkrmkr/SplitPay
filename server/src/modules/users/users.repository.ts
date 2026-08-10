import { prisma } from '../../prisma/client';
import { User } from '@prisma/client';

export async function findById(id: string): Promise<User | null> {
  return prisma.user.findUnique({ where: { id } });
}

export async function searchUsers(query: string, excludeUserId?: string): Promise<User[]> {
  return prisma.user.findMany({
    where: {
      AND: [
        {
          OR: [
            { name: { contains: query, mode: 'insensitive' } },
            { email: { contains: query, mode: 'insensitive' } },
          ],
        },
        excludeUserId ? { id: { not: excludeUserId } } : {},
      ],
    },
    take: 20,
    orderBy: { name: 'asc' },
  });
}

export async function updateUser(id: string, data: { name?: string; avatar?: string }): Promise<User> {
  return prisma.user.update({
    where: { id },
    data,
  });
}

