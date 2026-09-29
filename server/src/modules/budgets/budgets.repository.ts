import { prisma } from '../../prisma/client';
import { BudgetPeriod } from '@prisma/client';

export interface CreateBudgetData {
  userId: string;
  title: string;
  amount: number;
  categoryIds: string[];
  period: BudgetPeriod;
  startDate: Date;
  colorValue: number;
  iconCodePoint: number;
  alertThreshold: number;
}

export interface UpdateBudgetData {
  title?: string;
  amount?: number;
  categoryIds?: string[];
  period?: BudgetPeriod;
  startDate?: Date;
  colorValue?: number;
  iconCodePoint?: number;
  isArchived?: boolean;
  alertThreshold?: number;
}

export async function createBudget(data: CreateBudgetData) {
  return prisma.budget.create({ data });
}

export async function findAll(userId: string) {
  return prisma.budget.findMany({
    where: { userId },
    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
  });
}

export async function reorderActive(userId: string, budgetIds: string[]) {
  await prisma.$transaction(
    budgetIds.map((id, sortOrder) =>
      prisma.budget.updateMany({
        where: { id, userId, isArchived: false },
        data: { sortOrder },
      })
    )
  );
}

export async function findById(id: string, userId: string) {
  return prisma.budget.findFirst({ where: { id, userId } });
}

export async function updateBudget(id: string, data: UpdateBudgetData) {
  return prisma.budget.update({ where: { id }, data });
}

export async function deleteBudget(id: string) {
  return prisma.budget.delete({ where: { id } });
}
