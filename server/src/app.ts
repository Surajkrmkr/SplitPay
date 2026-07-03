import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import pinoHttp from 'pino-http';
import rateLimit from 'express-rate-limit';

import { env } from './configs/env';
import { logger } from './utils/logger';
import router from './routes/index';
import { errorHandler, notFoundHandler } from './middlewares/error.middleware';

const app: Application = express();

// ─── Security ────────────────────────────────────────────────────────────────
app.use(helmet());

// ─── CORS ────────────────────────────────────────────────────────────────────
const allowedOrigins = env.ALLOWED_ORIGINS.split(',').map((o) => o.trim());

app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl, Postman)
      if (!origin) {
        callback(null, true);
        return;
      }
      if (allowedOrigins.includes(origin) || allowedOrigins.includes('*')) {
        callback(null, true);
      } else {
        callback(new Error(`CORS policy: origin ${origin} not allowed`));
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

// ─── Body Parsing ────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ─── HTTP Logging ────────────────────────────────────────────────────────────
app.use(
  pinoHttp({
    logger,
    autoLogging: {
      ignore: (req) => req.url === `${env.API_PREFIX}/health`,
    },
  })
);

if (env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
}

// ─── Rate Limiting ───────────────────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.',
  },
  skip: (req) => req.url === `${env.API_PREFIX}/health`,
});

// app.use(limiter);

// ─── Routes ──────────────────────────────────────────────────────────────────
app.use(env.API_PREFIX, router);

// ─── 404 Handler ─────────────────────────────────────────────────────────────
app.use(notFoundHandler);

// ─── Global Error Handler ────────────────────────────────────────────────────
app.use(errorHandler);

export default app;
