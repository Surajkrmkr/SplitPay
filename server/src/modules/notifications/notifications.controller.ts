import { Request, Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../types';
import * as notificationsService from './notifications.service';
import { sendSuccess } from '../../utils/response';
import {
  RegisterTokenInput,
  GetNotificationsQuery,
} from '../../validations/notification.validation';

export async function registerToken(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    await notificationsService.registerToken(req.body as RegisterTokenInput);
    sendSuccess(res, null, 'FCM token registered');
  } catch (err) {
    next(err);
  }
}

export async function unregisterToken(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const { fcmToken } = req.body as { fcmToken: string };
    await notificationsService.unregisterToken(fcmToken);
    sendSuccess(res, null, 'FCM token removed');
  } catch (err) {
    next(err);
  }
}

export async function getNotifications(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    const result = await notificationsService.getNotifications(
      authReq.user.userId,
      req.query as unknown as GetNotificationsQuery
    );
    sendSuccess(res, result.notifications, 'Notifications retrieved', 200, result.meta);
  } catch (err) {
    next(err);
  }
}

export async function markRead(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    await notificationsService.markRead(req.params.id, authReq.user.userId);
    sendSuccess(res, null, 'Notification marked as read');
  } catch (err) {
    next(err);
  }
}

export async function markAllRead(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    await notificationsService.markAllRead(authReq.user.userId);
    sendSuccess(res, null, 'All notifications marked as read');
  } catch (err) {
    next(err);
  }
}

export async function deleteNotification(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    await notificationsService.deleteNotification(req.params.id, authReq.user.userId);
    sendSuccess(res, null, 'Notification deleted');
  } catch (err) {
    next(err);
  }
}

export async function deleteAllNotifications(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authReq = req as AuthenticatedRequest;
    await notificationsService.deleteAllNotifications(authReq.user.userId);
    sendSuccess(res, null, 'All notifications deleted');
  } catch (err) {
    next(err);
  }
}
