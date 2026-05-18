import { Router } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import { createSettlementSchema } from '../../validations/settlement.validation';
import * as settlementsController from './settlements.controller';

const router = Router();

/**
 * POST /settlements
 * Record a new settlement
 */
router.post('/', validate(createSettlementSchema), settlementsController.createSettlement);

export default router;
