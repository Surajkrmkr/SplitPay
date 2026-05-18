import https from 'https';
import { User } from '@prisma/client';
import { env } from '../../configs/env';
import { GoogleUser } from '../../types';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../../utils/jwt';
import { UnauthorizedError, BadRequestError } from '../../utils/app-error';
import * as authRepository from './auth.repository';
import * as usersRepository from '../users/users.repository';

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: Omit<User, 'googleId'>;
}

function fetchGoogleTokenInfo(idToken: string): Promise<GoogleUser> {
  return new Promise((resolve, reject) => {
    const url = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;

    https
      .get(url, (res) => {
        let data = '';

        res.on('data', (chunk: Buffer) => {
          data += chunk.toString();
        });

        res.on('end', () => {
          try {
            const parsed = JSON.parse(data) as Record<string, unknown>;

            if (res.statusCode !== 200) {
              reject(new UnauthorizedError('Invalid Google ID token'));
              return;
            }

            resolve(parsed as unknown as GoogleUser);
          } catch {
            reject(new BadRequestError('Failed to parse Google token info response'));
          }
        });
      })
      .on('error', (err) => {
        reject(new BadRequestError(`Failed to verify Google token: ${err.message}`));
      });
  });
}

export async function googleLogin(idToken: string): Promise<AuthResult> {
  // Verify with Google's token info endpoint
  const googleUser = await fetchGoogleTokenInfo(idToken);

  // Validate audience matches our client ID
  if (googleUser.aud !== env.GOOGLE_CLIENT_ID) {
    throw new UnauthorizedError('Google token audience mismatch');
  }

  if (!googleUser.email) {
    throw new BadRequestError('Google account does not have an email address');
  }

  // Find or create user
  let user = await authRepository.findUserByGoogleId(googleUser.sub);

  if (!user) {
    // Check if a user already exists with this email (link Google account to existing account)
    const existingUser = await authRepository.findUserByEmail(googleUser.email);

    if (existingUser) {
      // Link google account to existing user
      user = await authRepository.updateUser(existingUser.id, {
        googleId: googleUser.sub,
        avatar: existingUser.avatar ?? googleUser.picture,
      });
    } else {
      // Create brand new user
      user = await authRepository.createUser({
        email: googleUser.email,
        name: googleUser.name,
        googleId: googleUser.sub,
        avatar: googleUser.picture,
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

  // Clean up any expired sessions in the background (non-blocking)
  authRepository.deleteExpiredSessions().catch(() => {
    // Non-critical — silently ignore
  });

  const { googleId: _googleId, ...userWithoutGoogleId } = user;

  return {
    accessToken,
    refreshToken,
    user: userWithoutGoogleId,
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
