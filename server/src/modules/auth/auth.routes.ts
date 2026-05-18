import { Router } from 'express';
import { validate } from '../../middlewares/validate.middleware';
import { googleAuthSchema, refreshTokenSchema } from '../../validations/auth.validation';
import * as authController from './auth.controller';

const router = Router();

/**
 * POST /auth/google
 * Authenticate with a Google ID token
 */
router.post('/google', validate(googleAuthSchema), authController.googleLogin);

/**
 * POST /auth/refresh
 * Refresh access token using a refresh token
 */
router.post('/refresh', validate(refreshTokenSchema), authController.refresh);

/**
 * POST /auth/logout
 * Invalidate a refresh token session
 */
router.post('/logout', validate(refreshTokenSchema), authController.logout);

export default router;
