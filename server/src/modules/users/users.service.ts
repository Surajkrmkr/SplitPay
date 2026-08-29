import { User } from '@prisma/client';
import { NotFoundError } from '../../utils/app-error';
import { UpdateProfileInput } from '../../validations/user.validation';
import { admin } from '../../configs/firebase';
import { isAdFreeEmail } from '../../configs/premium-users';
import * as usersRepository from './users.repository';

export type SafeUser = Omit<User, 'googleId'> & { isAdFree: boolean };

function omitGoogleId(user: User): SafeUser {
  const { googleId: _googleId, ...safeUser } = user;
  // Ad-free if the user has a persisted premium flag OR is on the legacy
  // hardcoded allowlist (internal testers/VIPs granted before the
  // `is_premium` column existed).
  return { ...safeUser, isAdFree: user.isPremium || isAdFreeEmail(user.email) };
}

export async function getMe(userId: string): Promise<SafeUser> {
  const user = await usersRepository.findById(userId);

  if (!user) {
    throw new NotFoundError('User not found');
  }

  return omitGoogleId(user);
}

export async function updateMe(userId: string, input: UpdateProfileInput): Promise<SafeUser> {
  const existing = await usersRepository.findById(userId);
  if (!existing) {
    throw new NotFoundError('User not found');
  }

  let newName: string | undefined;
  if (input.firstName !== undefined || input.lastName !== undefined) {
    const fn = input.firstName ?? '';
    const ln = input.lastName ?? '';
    newName = `${fn} ${ln}`.trim();
  } else if (input.name !== undefined) {
    newName = input.name.trim();
  }

  const updated = await usersRepository.updateUser(userId, {
    ...(newName ? { name: newName } : {}),
  });

  return omitGoogleId(updated);
}

export async function search(query: string, currentUserId: string): Promise<SafeUser[]> {
  const users = await usersRepository.searchUsers(query, currentUserId);
  return users.map(omitGoogleId);
}

export async function deleteMe(userId: string): Promise<void> {
  const user = await usersRepository.findById(userId);
  if (!user) {
    throw new NotFoundError('User not found');
  }

  // Delete user record and related data from database
  await usersRepository.deleteUser(userId);

  // Best effort delete from Firebase Auth if firebaseUid exists
  if (user.firebaseUid) {
    try {
      await admin.auth().deleteUser(user.firebaseUid);
    } catch (err) {
      console.warn(`Failed to delete Firebase user ${user.firebaseUid}:`, err);
    }
  }
}


