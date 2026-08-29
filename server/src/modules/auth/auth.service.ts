import { User } from '@prisma/client';
import { admin } from '../../configs/firebase';
import { isAdFreeEmail } from '../../configs/premium-users';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../../utils/jwt';
import { UnauthorizedError, BadRequestError } from '../../utils/app-error';
import * as authRepository from './auth.repository';
import * as usersRepository from '../users/users.repository';

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: Omit<User, 'googleId' | 'firebaseUid'> & { isAdFree: boolean };
}

/**
 * Verify a Firebase ID token (from any provider: Google, Apple, Email, etc.)
 * using the Firebase Admin SDK and return normalised user fields.
 */
async function verifyFirebaseToken(idToken: string) {
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);

    if (!decoded.email) {
      throw new BadRequestError('Firebase account does not have an email address');
    }

    return {
      uid: decoded.uid,
      email: decoded.email,
      name: decoded.name ?? decoded.email.split('@')[0],
      picture: decoded.picture,
      email_verified: decoded.email_verified,
      sign_in_provider: decoded.firebase?.sign_in_provider ?? 'unknown',
    };
  } catch (err) {
    if (err instanceof BadRequestError) throw err;

    // Fallback for raw Google OAuth2 ID tokens (iss: accounts.google.com)
    try {
      const res = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
      if (res.ok) {
        const payload = (await res.json()) as {
          sub?: string;
          email?: string;
          name?: string;
          picture?: string;
          email_verified?: string | boolean;
        };

        if (payload.email && payload.sub) {
          return {
            uid: `google:${payload.sub}`,
            email: payload.email,
            name: payload.name ?? payload.email.split('@')[0],
            picture: payload.picture,
            email_verified: payload.email_verified === true || payload.email_verified === 'true',
            sign_in_provider: 'google.com',
          };
        }
      }
    } catch {
      // Ignore fallback error
    }

    console.error('Firebase token verification error:', err);
    throw new UnauthorizedError('Invalid Firebase ID token');
  }
}

/**
 * POST /auth/google
 *
 * Accepts a Firebase ID token from **any** Firebase sign-in provider
 * (Google OAuth, Apple Sign-In, Email/Password, etc.) and exchanges it
 * for a backend JWT access + refresh token pair.
 */
export async function googleLogin(idToken: string): Promise<AuthResult> {
  // Verify the Firebase ID token (works for Google, Apple, any provider)
  const firebaseUser = await verifyFirebaseToken(idToken);

  // --- Look up existing user ---
  // 1) Try by Firebase UID first (most reliable, provider-agnostic)
  let user = await authRepository.findUserByFirebaseUid(firebaseUser.uid);

  if (!user) {
    // 2) Fallback: look up by email to link accounts created via other providers
    const existingUser = await authRepository.findUserByEmail(firebaseUser.email);

    if (existingUser) {
      // Link this Firebase UID to the existing account
      user = await authRepository.updateUser(existingUser.id, {
        firebaseUid: firebaseUser.uid,
        avatar: existingUser.avatar ?? firebaseUser.picture,
        // Populate googleId if signing in via Google and it's not already set
        ...(firebaseUser.sign_in_provider === 'google.com' && !existingUser.googleId
          ? { googleId: firebaseUser.uid }
          : {}),
      });
    } else {
      // 3) Brand new user
      user = await authRepository.createUser({
        email: firebaseUser.email,
        name: firebaseUser.name,
        firebaseUid: firebaseUser.uid,
        // Also populate googleId for Google sign-ins
        ...(firebaseUser.sign_in_provider === 'google.com' ? { googleId: firebaseUser.uid } : {}),
        avatar: firebaseUser.picture,
      });
    }
  }

  // Generate tokens
  const refreshToken = generateRefreshToken({ userId: user.id });
  const accessToken = generateAccessToken({ userId: user.id, email: user.email });

  // Calculate session expiry (7 days from now)
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 7);

  // Persist the session
  await authRepository.createSession({
    userId: user.id,
    refreshToken,
    expiresAt,
  });

  // Clean up expired sessions in the background (non-blocking)
  authRepository.deleteExpiredSessions().catch(() => {
    // Non-critical — silently ignore
  });

  const { googleId: _googleId, firebaseUid: _firebaseUid, ...userWithoutProviderIds } = user;

  return {
    accessToken,
    refreshToken,
    // Ad-free if the user has a persisted premium flag OR is on the legacy
    // hardcoded allowlist (internal testers/VIPs granted before the
    // `is_premium` column existed).
    user: { ...userWithoutProviderIds, isAdFree: user.isPremium || isAdFreeEmail(user.email) },
  };
}

export async function refresh(refreshToken: string): Promise<{ accessToken: string }> {
  // Verify JWT signature and check expiry claim
  verifyRefreshToken(refreshToken);

  // Find session in database
  const session = await authRepository.findSession(refreshToken);

  if (!session) {
    throw new UnauthorizedError('Refresh token not found. Please log in again.');
  }

  // Double-check DB-level expiry
  if (session.expiresAt < new Date()) {
    await authRepository.deleteSession(refreshToken);
    throw new UnauthorizedError('Refresh token has expired. Please log in again.');
  }

  // Look up the user to get the current email (may have changed)
  const user = await usersRepository.findById(session.userId);

  if (!user) {
    await authRepository.deleteSession(refreshToken);
    throw new UnauthorizedError('User account no longer exists.');
  }

  const accessToken = generateAccessToken({
    userId: user.id,
    email: user.email,
  });

  return { accessToken };
}

export async function logout(refreshToken: string): Promise<void> {
  // Delete the session — no error if not found (idempotent)
  await authRepository.deleteSession(refreshToken);
}
