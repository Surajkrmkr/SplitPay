import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as service from './transactions.service';
import { sendSuccess, sendCreated } from '../../utils/response';
import {
  CreateTransactionInput,
  UpdateTransactionInput,
  ListTransactionsQuery,
} from '../../validations/transaction.validation';

export async function createTransaction(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const tx = await service.createTransaction(userId, req.body as CreateTransactionInput);
    sendCreated(res, tx, 'Transaction created');
  } catch (err) {
    next(err);
  }
}

export async function getTransactions(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const result = await service.getTransactions(userId, req.query as unknown as ListTransactionsQuery);
    const { items, total, page, limit, totalPages } = result;
    sendSuccess(res, items, 'Transactions retrieved', 200, { total, page, limit, totalPages });
  } catch (err) {
    next(err);
  }
}

export async function getTransactionById(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const tx = await service.getTransactionById(userId, req.params.id);
    sendSuccess(res, tx, 'Transaction retrieved');
  } catch (err) {
    next(err);
  }
}

export async function updateTransaction(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const tx = await service.updateTransaction(userId, req.params.id, req.body as UpdateTransactionInput);
    sendSuccess(res, tx, 'Transaction updated');
  } catch (err) {
    next(err);
  }
}

export async function deleteTransaction(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    await service.deleteTransaction(userId, req.params.id);
    sendSuccess(res, null, 'Transaction deleted');
  } catch (err) {
    next(err);
  }
}
