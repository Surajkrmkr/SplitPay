import { prisma } from '../../prisma/client';

export interface CreateCategoryData {
  userId: string;
  localId: string;
  label: string;
  colorValue: number;
  iconCodePoint: number;
}

export async function upsertByLocalId(userId: string, localId: string, data: Omit<CreateCategoryData, 'userId' | 'localId'>) {
  return prisma.userCategory.upsert({
    where: { userId_localId: { userId, localId } },
    create: { userId, localId, ...data },
    update: { ...data },
  });
}

export async function findAll(userId: string) {
  return prisma.userCategory.findMany({
    where: { userId, deletedAt: null },
    orderBy: { createdAt: 'asc' },
  });
}

export async function findById(id: string, userId: string) {
  return prisma.userCategory.findFirst({ where: { id, userId, deletedAt: null } });
}

export async function findByLocalId(userId: string, localId: string) {
  return prisma.userCategory.findUnique({
    where: { userId_localId: { userId, localId } },
  });
}

export async function updateCategory(id: string, data: { label?: string; colorValue?: number; iconCodePoint?: number }) {
  return prisma.userCategory.update({ where: { id }, data });
}

export async function softDelete(id: string) {
  return prisma.userCategory.update({ where: { id }, data: { deletedAt: new Date() } });
}

export async function softDeleteByLocalId(userId: string, localId: string) {
  const cat = await prisma.userCategory.findUnique({
    where: { userId_localId: { userId, localId } },
  });
  if (!cat) return null;
  return prisma.userCategory.update({ where: { id: cat.id }, data: { deletedAt: new Date() } });
}

export async function findChangedSince(userId: string, since: Date) {
  return prisma.userCategory.findMany({
    where: { userId, updatedAt: { gt: since } },
    orderBy: { updatedAt: 'asc' },
  });
}
