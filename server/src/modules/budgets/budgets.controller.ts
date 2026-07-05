import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as service from './budgets.service';
import { sendSuccess, sendCreated } from '../../utils/response';
import { CreateBudgetInput, UpdateBudgetInput } from '../../validations/budget.validation';

export async function createBudget(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const budget = await service.createBudget(userId, req.body as CreateBudgetInput);
    sendCreated(res, budget, 'Budget created');
  } catch (err) {
    next(err);
  }
}

export async function getBudgets(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const budgets = await service.getBudgets(userId);
    sendSuccess(res, budgets, 'Budgets retrieved');
  } catch (err) {
    next(err);
  }
}

export async function updateBudget(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const budget = await service.updateBudget(userId, req.params.id, req.body as UpdateBudgetInput);
    sendSuccess(res, budget, 'Budget updated');
  } catch (err) {
    next(err);
  }
}

export async function deleteBudget(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    await service.deleteBudget(userId, req.params.id);
    sendSuccess(res, null, 'Budget deleted');
  } catch (err) {
    next(err);
  }
}
