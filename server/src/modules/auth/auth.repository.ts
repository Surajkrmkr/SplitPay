import { prisma } from '../../prisma/client';
import { User, Session } from '@prisma/client';

export interface CreateUserData {
  email: string;
  name: string;
  googleId?: string;
  firebaseUid?: string;
  avatar?: string;
}

export interface UpdateUserData {
  name?: string;
  avatar?: string;
  googleId?: string;
  firebaseUid?: string;
}

export interface CreateSessionData {
  userId: string;
  refreshToken: string;
  expiresAt: Date;
}

export async function findUserByGoogleId(googleId: string): Promise<User | null> {
  return prisma.user.findUnique({ where: { googleId } });
}

export async function findUserByFirebaseUid(firebaseUid: string): Promise<User | null> {
  return prisma.user.findUnique({ where: { firebaseUid } });
}

export async function findUserByEmail(email: string): Promise<User | null> {
  return prisma.user.findUnique({ where: { email } });
}

export async function createUser(data: CreateUserData): Promise<User> {
  return prisma.user.create({ data });
}

export async function updateUser(id: string, data: UpdateUserData): Promise<User> {
  return prisma.user.update({ where: { id }, data });
}

export async function createSession(data: CreateSessionData): Promise<Session> {
  return prisma.session.create({ data });
}

export async function findSession(refreshToken: string): Promise<Session | null> {
  return prisma.session.findUnique({ where: { refreshToken } });
}

export async function deleteSession(refreshToken: string): Promise<void> {
  await prisma.session.deleteMany({ where: { refreshToken } });
}

export async function deleteExpiredSessions(): Promise<void> {
  await prisma.session.deleteMany({
    where: { expiresAt: { lt: new Date() } },
  });
}
