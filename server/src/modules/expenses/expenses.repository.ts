import { prisma } from '../../prisma/client';
import { Expense, SplitType } from '@prisma/client';
import { Decimal } from '@prisma/client/runtime/library';

export interface CreateExpenseData {
  groupId: string;
  title: string;
  amount: number;
  paidById: string;
  splitType: SplitType;
  notes?: string;
  date?: Date;
  participants: {
    userId: string;
    share: number;
    percentage?: number;
  }[];
}

export type ExpenseWithDetails = Expense & {
  paidBy: { id: string; name: string; email: string; avatar: string | null };
  participants: {
    id: string;
    userId: string;
    share: Decimal;
    percentage: Decimal | null;
    user: { id: string; name: string; email: string; avatar: string | null };
  }[];
};

export async function createExpense(data: CreateExpenseData): Promise<ExpenseWithDetails> {
  const { participants, ...expenseData } = data;

  return prisma.$transaction(async (tx) => {
    const expense = await tx.expense.create({
      data: {
        ...expenseData,
        date: expenseData.date ?? new Date(),
        participants: {
          create: participants.map((p) => ({
            userId: p.userId,
            share: p.share,
            percentage: p.percentage ?? null,
          })),
        },
      },
      include: {
        paidBy: { select: { id: true, name: true, email: true, avatar: true } },
        participants: {
          include: {
            user: { select: { id: true, name: true, email: true, avatar: true } },
          },
        },
      },
    });

    return expense;
  });
}

export async function findGroupExpenses(groupId: string): Promise<ExpenseWithDetails[]> {
  return prisma.expense.findMany({
    where: { groupId },
    include: {
      paidBy: { select: { id: true, name: true, email: true, avatar: true } },
      participants: {
        include: {
          user: { select: { id: true, name: true, email: true, avatar: true } },
        },
      },
    },
    orderBy: { date: 'desc' },
  });
}

export async function findExpenseById(expenseId: string): Promise<ExpenseWithDetails | null> {
  return prisma.expense.findUnique({
    where: { id: expenseId },
    include: {
      paidBy: { select: { id: true, name: true, email: true, avatar: true } },
      participants: {
        include: {
          user: { select: { id: true, name: true, email: true, avatar: true } },
        },
      },
    },
  });
}

export async function updateExpense(
  expenseId: string,
  data: {
    title?: string;
    amount?: number;
    paidById?: string;
    splitType?: string;
    notes?: string | null;
    date?: Date;
    participants?: { userId: string; share: number; percentage?: number }[];
  }
): Promise<ExpenseWithDetails> {
  const { participants, ...expenseData } = data;

  return prisma.$transaction(async (tx) => {
    if (participants) {
      await tx.expenseParticipant.deleteMany({ where: { expenseId } });
      await tx.expenseParticipant.createMany({
        data: participants.map((p) => ({ expenseId, userId: p.userId, share: p.share, percentage: p.percentage ?? null })),
      });
    }

    return tx.expense.update({
      where: { id: expenseId },
      data: expenseData as Parameters<typeof tx.expense.update>[0]['data'],
      include: {
        paidBy: { select: { id: true, name: true, email: true, avatar: true } },
        participants: { include: { user: { select: { id: true, name: true, email: true, avatar: true } } } },
      },
    });
  });
}

export async function deleteExpense(expenseId: string): Promise<void> {
  await prisma.expense.delete({ where: { id: expenseId } });
}

export async function findGroupExpensesForBalance(groupId: string) {
  return prisma.expense.findMany({
    where: { groupId },
    select: {
      id: true,
      amount: true,
      paidById: true,
      participants: {
        select: {
          userId: true,
          share: true,
        },
      },
    },
  });
}
