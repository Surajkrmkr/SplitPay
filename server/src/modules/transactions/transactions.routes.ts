import { Router } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import {
  createTransactionSchema,
  updateTransactionSchema,
  listTransactionsSchema,
} from '../../validations/transaction.validation';
import * as controller from './transactions.controller';

const router = Router();

router.get('/', validate(listTransactionsSchema, 'query'), controller.getTransactions);
router.post('/', validate(createTransactionSchema), controller.createTransaction);
router.get('/:id', controller.getTransactionById);
router.patch('/:id', validate(updateTransactionSchema), controller.updateTransaction);
router.delete('/:id', controller.deleteTransaction);

export default router;
