import { User } from '@prisma/client';
import { NotFoundError } from '../../utils/app-error';
import * as usersRepository from './users.repository';

export type SafeUser = Omit<User, 'googleId'>;

function omitGoogleId(user: User): SafeUser {
  const { googleId: _googleId, ...safeUser } = user;
  return safeUser;
}

export async function getMe(userId: string): Promise<SafeUser> {
  const user = await usersRepository.findById(userId);

  if (!user) {
    throw new NotFoundError('User not found');
  }

  return omitGoogleId(user);
}

export async function search(query: string, currentUserId: string): Promise<SafeUser[]> {
  const users = await usersRepository.searchUsers(query, currentUserId);
  return users.map(omitGoogleId);
}
