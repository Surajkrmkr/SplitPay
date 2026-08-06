import * as admin from 'firebase-admin';
import { env } from './env';

let app: admin.app.App;

if (admin.apps.length === 0) {
  if (env.FIREBASE_SERVICE_ACCOUNT_KEY) {
    try {
      const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_KEY) as admin.ServiceAccount;
      app = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    } catch {
      console.error('❌ Failed to parse FIREBASE_SERVICE_ACCOUNT_KEY — Firebase Admin SDK not initialized');
      app = admin.initializeApp();
    }
  } else {
    // No key provided — initialize with application default credentials (for local dev)
    app = admin.initializeApp();
  }
} else {
  app = admin.apps[0]!;
}

export { admin, app };
