import { admin } from '../configs/firebase';
import { env } from '../configs/env';
import { logger } from './logger';

// The Firebase Admin app is already initialized once, at import time, by
// `configs/firebase` (used for ID token verification). Calling
// `admin.initializeApp()` again here — as this file used to — throws
// "Firebase app named '[DEFAULT]' already exists", which was silently
// swallowed below and permanently disabled push notifications. Reuse the
// shared app instead of re-initializing.
function ensureInitialized(): boolean {
  if (!env.FIREBASE_SERVICE_ACCOUNT_KEY) {
    logger.warn('FIREBASE_SERVICE_ACCOUNT_KEY not set — FCM push notifications disabled');
    return false;
  }
  return true;
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
