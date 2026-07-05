import { BudgetPeriod } from '@prisma/client';
import { NotFoundError, ForbiddenError } from '../../utils/app-error';
import * as repo from './budgets.repository';
import { CreateBudgetInput, UpdateBudgetInput } from '../../validations/budget.validation';

export async function createBudget(userId: string, input: CreateBudgetInput) {
  return repo.createBudget({
    userId,
    title: input.title,
    amount: input.amount,
    categoryIds: input.categoryIds,
    period: input.period as BudgetPeriod,
    startDate: new Date(input.startDate),
    colorValue: input.colorValue,
    iconCodePoint: input.iconCodePoint,
    alertThreshold: input.alertThreshold,
  });
}

export async function getBudgets(userId: string) {
  return repo.findAll(userId);
}

export async function updateBudget(userId: string, id: string, input: UpdateBudgetInput) {
  const budget = await repo.findById(id, userId);
  if (!budget) throw new NotFoundError('Budget not found');
  if (budget.userId !== userId) throw new ForbiddenError('Not your budget');

  return repo.updateBudget(id, {
    ...(input.title !== undefined ? { title: input.title } : {}),
    ...(input.amount !== undefined ? { amount: input.amount } : {}),
    ...(input.categoryIds !== undefined ? { categoryIds: input.categoryIds } : {}),
    ...(input.period ? { period: input.period as BudgetPeriod } : {}),
    ...(input.startDate ? { startDate: new Date(input.startDate) } : {}),
    ...(input.colorValue !== undefined ? { colorValue: input.colorValue } : {}),
    ...(input.iconCodePoint !== undefined ? { iconCodePoint: input.iconCodePoint } : {}),
    ...(input.isArchived !== undefined ? { isArchived: input.isArchived } : {}),
    ...(input.alertThreshold !== undefined ? { alertThreshold: input.alertThreshold } : {}),
  });
}

export async function deleteBudget(userId: string, id: string) {
  const budget = await repo.findById(id, userId);
  if (!budget) throw new NotFoundError('Budget not found');
  if (budget.userId !== userId) throw new ForbiddenError('Not your budget');

  await repo.deleteBudget(id);
}
