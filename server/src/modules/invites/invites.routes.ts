import { Router } from 'express';
import * as invitesController from './invites.controller';

const router = Router();

router.get('/:code', invitesController.getInviteInfo);
router.post('/:code/join', invitesController.joinViaInvite);

export default router;
