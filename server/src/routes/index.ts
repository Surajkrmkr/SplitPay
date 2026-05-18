import { Router, Request, Response } from 'express';
import { authenticate } from '../middlewares/auth.middleware';
import authRoutes from '../modules/auth/auth.routes';
import usersRoutes from '../modules/users/users.routes';
import groupsRoutes from '../modules/groups/groups.routes';
import expensesRoutes from '../modules/expenses/expenses.routes';
import settlementsRoutes from '../modules/settlements/settlements.routes';
import invitesRoutes from '../modules/invites/invites.routes';
import * as expensesController from '../modules/expenses/expenses.controller';
import * as settlementsController from '../modules/settlements/settlements.controller';
import * as activityController from '../modules/activity/activity.controller';

const router = Router();

// Health check endpoint (no auth required)
router.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    service: 'splitpay-api',
    timestamp: new Date().toISOString(),
  });
});

// Auth routes (public — no authentication required)
router.use('/auth', authRoutes);

// Protected routes (require valid JWT)
router.use('/users', authenticate, usersRoutes);
router.use('/groups', authenticate, groupsRoutes);
router.use('/expenses', authenticate, expensesRoutes);
router.use('/settlements', authenticate, settlementsRoutes);
router.use('/invites', authenticate, invitesRoutes);

// Group-scoped sub-resources (mounted under /groups/:id/...)
router.get('/groups/:id/expenses', authenticate, expensesController.getGroupExpenses);
router.get('/groups/:id/balances', authenticate, expensesController.getGroupBalances);
router.get('/groups/:id/settlements', authenticate, settlementsController.getGroupSettlements);
router.get('/groups/:id/activity', authenticate, activityController.getGroupActivity);

export default router;
