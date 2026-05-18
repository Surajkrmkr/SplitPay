import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as expensesService from './expenses.service';
import { sendSuccess, sendCreated } from '../../utils/response';
import { CreateExpenseInput, UpdateExpenseInput } from '../../validations/expense.validation';

export async function createExpense(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    const expense = await expensesService.createExpense(
      authReq.user.userId,
      req.body as CreateExpenseInput
    );
    sendCreated(res, expense, 'Expense created successfully');
  } catch (err) {
    next(err);
  }
}

export async function getGroupExpenses(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    const { id: groupId } = req.params;
    const expenses = await expensesService.getGroupExpenses(groupId, authReq.user.userId);
    sendSuccess(res, expenses, 'Expenses retrieved');
  } catch (err) {
    next(err);
  }
}

export async function updateExpense(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    const expense = await expensesService.updateExpense(req.params.id, authReq.user.userId, req.body as UpdateExpenseInput);
    sendSuccess(res, expense, 'Expense updated successfully');
  } catch (err) { next(err); }
}

export async function deleteExpense(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    await expensesService.deleteExpense(req.params.id, authReq.user.userId);
    sendSuccess(res, null, 'Expense deleted successfully');
  } catch (err) { next(err); }
}

export async function getGroupBalances(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    const { id: groupId } = req.params;
    const result = await expensesService.getGroupBalances(groupId, authReq.user.userId);
    sendSuccess(res, result, 'Balances calculated');
  } catch (err) {
    next(err);
  }
}
