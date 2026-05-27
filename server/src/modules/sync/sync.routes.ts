import { Router } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import { syncPushSchema, syncPullSchema } from '../../validations/sync.validation';
import * as controller from './sync.controller';

const router = Router();

router.post('/transactions', validate(syncPushSchema), controller.pushChanges);
router.get('/changes', validate(syncPullSchema, 'query'), controller.pullChanges);

export default router;
