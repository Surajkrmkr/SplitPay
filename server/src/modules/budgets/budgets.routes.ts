import { Router } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import {
  createBudgetSchema,
  reorderBudgetsSchema,
  updateBudgetSchema,
} from '../../validations/budget.validation';
import * as controller from './budgets.controller';

const router = Router();

router.get('/', controller.getBudgets);
router.patch('/order', validate(reorderBudgetsSchema), controller.reorderBudgets);
router.post('/', validate(createBudgetSchema), controller.createBudget);
router.patch('/:id', validate(updateBudgetSchema), controller.updateBudget);
router.delete('/:id', controller.deleteBudget);

export default router;
