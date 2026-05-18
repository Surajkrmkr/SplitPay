import { Router } from 'express';
import * as activityController from './activity.controller';

const router = Router({ mergeParams: true });

/**
 * GET /groups/:id/activity
 * Get the activity feed for a group (last 50 events)
 */
router.get('/', activityController.getGroupActivity);

export default router;
