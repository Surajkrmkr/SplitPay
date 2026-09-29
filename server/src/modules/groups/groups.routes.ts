import { Router } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import {
  createGroupSchema,
  addMemberSchema,
  updateGroupSchema,
  updateMemberRoleSchema,
  reorderGroupsSchema,
  paymentReminderSchema,
} from '../../validations/group.validation';
import * as groupsController from './groups.controller';

const router = Router();

router.post('/', validate(createGroupSchema), groupsController.createGroupHandler);
router.get('/', groupsController.getGroupsHandler);
router.patch('/order', validate(reorderGroupsSchema), groupsController.reorderGroupsHandler);
router.post(
  '/:id/payment-reminders',
  validate(paymentReminderSchema),
  groupsController.paymentReminderHandler
);
router.get('/:id', groupsController.getGroupHandler);
router.patch('/:id', validate(updateGroupSchema), groupsController.updateGroupHandler);
router.delete('/:id', groupsController.deleteGroupHandler);
router.post('/:id/members', validate(addMemberSchema), groupsController.addMemberHandler);
router.delete('/:id/members/:memberId', groupsController.removeMemberHandler);
router.patch(
  '/:id/members/:memberId',
  validate(updateMemberRoleSchema),
  groupsController.updateMemberRoleHandler
);
router.post('/:id/invites', groupsController.generateInviteHandler);
router.get('/:id/invites/active', groupsController.getActiveInviteHandler);

export default router;
