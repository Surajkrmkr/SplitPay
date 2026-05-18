import 'dotenv/config';
import { env } from './configs/env';
import { logger } from './utils/logger';
import { prisma } from './prisma/client';
import app from './app';
import { Server } from 'http';

let server: Server;

async function start(): Promise<void> {
  // Verify database connection
  await prisma.$connect();
  logger.info('Database connection established');

  server = app.listen(env.PORT, () => {
    logger.info(
      {
        port: env.PORT,
        env: env.NODE_ENV,
        prefix: env.API_PREFIX,
      },
      `SplitPay API server started`
    );
  });
}

async function gracefulShutdown(signal: string): Promise<void> {
  logger.info({ signal }, 'Shutdown signal received. Gracefully shutting down...');

  // Stop accepting new connections
  if (server) {
    server.close(async (err) => {
      if (err) {
        logger.error({ err }, 'Error closing HTTP server');
        process.exit(1);
      }

      // Disconnect Prisma
      await prisma.$disconnect();
      logger.info('Database connection closed');
      logger.info('Shutdown complete');
      process.exit(0);
    });
  } else {
    await prisma.$disconnect();
    process.exit(0);
  }

  // Force shutdown after 10 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10_000).unref();
}

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason: unknown) => {
  logger.error({ reason }, 'Unhandled Promise Rejection');
  gracefulShutdown('unhandledRejection').catch(() => process.exit(1));
});

// Handle uncaught exceptions
process.on('uncaughtException', (err: Error) => {
  logger.fatal({ err }, 'Uncaught Exception');
  gracefulShutdown('uncaughtException').catch(() => process.exit(1));
});

// Graceful shutdown on SIGTERM (Docker/Kubernetes stop)
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

// Graceful shutdown on SIGINT (Ctrl+C)
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

start().catch((err) => {
  logger.fatal({ err }, 'Failed to start server');
  process.exit(1);
});
