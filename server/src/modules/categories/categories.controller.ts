import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as service from './categories.service';
import { sendSuccess, sendCreated } from '../../utils/response';
import { CreateCategoryInput, UpdateCategoryInput } from '../../validations/category.validation';

export async function createCategory(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const cat = await service.createCategory(userId, req.body as CreateCategoryInput);
    sendCreated(res, cat, 'Category created');
  } catch (err) {
    next(err);
  }
}

export async function getCategories(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const cats = await service.getCategories(userId);
    sendSuccess(res, cats, 'Categories retrieved');
  } catch (err) {
    next(err);
  }
}

export async function updateCategory(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    const cat = await service.updateCategory(userId, req.params.id, req.body as UpdateCategoryInput);
    sendSuccess(res, cat, 'Category updated');
  } catch (err) {
    next(err);
  }
}

export async function deleteCategory(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { userId } = (req as AuthenticatedRequest).user;
    await service.deleteCategory(userId, req.params.id);
    sendSuccess(res, null, 'Category deleted');
  } catch (err) {
    next(err);
  }
}
