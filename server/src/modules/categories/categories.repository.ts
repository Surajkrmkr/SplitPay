import { prisma } from '../../prisma/client';

export interface CreateCategoryData {
  userId: string;
  label: string;
  colorValue: number;
  iconCodePoint: number;
}

export async function createCategory(data: CreateCategoryData) {
  return prisma.userCategory.create({ data });
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

export async function updateCategory(id: string, data: { label?: string; colorValue?: number; iconCodePoint?: number }) {
  return prisma.userCategory.update({ where: { id }, data });
}

export async function softDelete(id: string) {
  return prisma.userCategory.update({ where: { id }, data: { deletedAt: new Date() } });
}
