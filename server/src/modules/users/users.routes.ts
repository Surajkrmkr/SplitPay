import { Router, Request, Response, NextFunction } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import { searchQuerySchema, updateProfileSchema } from '../../validations/user.validation';
import { AuthenticatedRequest } from '../../types';
import * as usersController from './users.controller';

const router = Router();

/**
 * GET /users/me
 * Get the currently authenticated user's profile
 */
router.get('/me', (req: Request, res: Response, next: NextFunction) =>
  usersController.getMe(req as AuthenticatedRequest, res, next)
);

/**
 * PATCH /users/me
 * Update current user's profile (name / first name / last name)
 */
router.patch(
  '/me',
  validate(updateProfileSchema),
  (req: Request, res: Response, next: NextFunction) =>
    usersController.updateMe(req as AuthenticatedRequest, res, next)
);


/**
 * GET /users/search?q=query
 * Search users by name or email
 */
router.get(
  '/search',
  validate(searchQuerySchema, 'query'),
  (req: Request, res: Response, next: NextFunction) =>
    usersController.searchUsers(req as AuthenticatedRequest, res, next)
);

export default router;
