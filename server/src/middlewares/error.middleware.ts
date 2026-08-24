import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { Prisma } from '@prisma/client';
import { AppError } from '../utils/app-error';
import { sendError } from '../utils/response';
import { logger } from '../utils/logger';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): Response {
  // Zod validation errors
  if (err instanceof ZodError) {
    const errors = err.errors.map((e) => ({
      field: e.path.join('.'),
      message: e.message,
    }));
    return sendError(res, 'Validation failed', 400, errors);
  }

  // Operational errors (AppError subclasses)
  if (err instanceof AppError) {
    if (!err.isOperational) {
      logger.error({ err, url: req.url, method: req.method }, 'Non-operational AppError');
    }
    return sendError(res, err.message, err.statusCode);
  }

  // Prisma Database errors
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    logger.error({ err, code: err.code, meta: err.meta, url: req.url, method: req.method }, 'Prisma error');
    if (err.code === 'P2002') {
      return sendError(res, 'A record with this unique value already exists', 409);
    }
    if (err.code === 'P2025') {
      return sendError(res, 'Requested record was not found', 404);
    }
    return sendError(res, `Database error (${err.code})`, 400);
  }

  if (
    err instanceof Prisma.PrismaClientUnknownRequestError ||
    err instanceof Prisma.PrismaClientInitializationError
  ) {
    logger.error({ err, url: req.url, method: req.method }, 'Prisma database client error');
    return sendError(res, 'Database error occurred. Please try again later.', 500);
  }

  // Unknown / unexpected errors
  logger.error({ err, url: req.url, method: req.method }, 'Unhandled error');

  return sendError(
    res,
    'An unexpected error occurred. Please try again later.',
    500
  );
}

export function notFoundHandler(req: Request, res: Response): Response {
  return sendError(res, `Route ${req.method} ${req.url} not found`, 404);
}
