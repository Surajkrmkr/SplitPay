import { Router } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import { createExpenseSchema, updateExpenseSchema } from '../../validations/expense.validation';
import * as expensesController from './expenses.controller';

const router = Router();

router.post('/', validate(createExpenseSchema), expensesController.createExpense);
router.patch('/:id', validate(updateExpenseSchema), expensesController.updateExpense);
router.delete('/:id', expensesController.deleteExpense);

export default router;
