import * as admin from 'firebase-admin';
import { env } from '../configs/env';
import { logger } from './logger';

let initialized = false;

function ensureInitialized(): boolean {
  if (initialized) return true;
  if (!env.FIREBASE_SERVICE_ACCOUNT_KEY) {
    logger.warn('FIREBASE_SERVICE_ACCOUNT_KEY not set — FCM push notifications disabled');
    return false;
  }
  try {
    const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_KEY);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    initialized = true;
    logger.info('Firebase Admin SDK initialized');
    return true;
  } catch (err) {
    logger.error({ err }, 'Failed to initialize Firebase Admin SDK');
    return false;
  }
}

export interface FcmPayload {
  tokens: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Sends a multicast FCM message. Silently ignores invalid/stale tokens.
 * Returns the number of successful deliveries.
 */
export async function sendPushNotification(payload: FcmPayload): Promise<number> {
  if (!ensureInitialized() || payload.tokens.length === 0) return 0;

  try {
    const response = await admin.messaging().sendEachForMulticast({
      tokens: payload.tokens,
      notification: { title: payload.title, body: payload.body },
      data: payload.data ?? {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'splitpay_high',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    });

    if (response.failureCount > 0) {
      response.responses.forEach((r, idx) => {
        if (!r.success) {
          logger.debug({ token: payload.tokens[idx], error: r.error?.code }, 'FCM delivery failed');
        }
      });
    }

    return response.successCount;
  } catch (err) {
    logger.error({ err }, 'FCM sendEachForMulticast failed');
    return 0;
  }
}
