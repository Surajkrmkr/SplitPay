import { Router } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import {
  registerTokenSchema,
  getNotificationsSchema,
} from '../../validations/notification.validation';
import * as notificationsController from './notifications.controller';

const router = Router();

// GET  /notifications          — list with pagination
router.get(
  '/',
  validate(getNotificationsSchema, 'query'),
  notificationsController.getNotifications
);

// PATCH /notifications/read-all
router.patch('/read-all', notificationsController.markAllRead);

// PATCH /notifications/:id/read
router.patch('/:id/read', notificationsController.markRead);

// DELETE /notifications      — clear all
router.delete('/', notificationsController.deleteAllNotifications);

// DELETE /notifications/:id
router.delete('/:id', notificationsController.deleteNotification);

export default router;
