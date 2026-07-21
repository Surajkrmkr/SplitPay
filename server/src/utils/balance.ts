export interface RawBalance {
  fromUserId: string;
  toUserId: string;
  amount: number;
}

export interface SimplifiedDebt {
  fromUserId: string;
  toUserId: string;
  amount: number;
}

/**
 * Simplifies a list of debts using a greedy min-cash-flow algorithm.
 * Reduces the number of transactions needed to settle all debts.
 */
export function simplifyDebts(rawBalances: RawBalance[]): SimplifiedDebt[] {
  // Build net balance map: positive = net creditor, negative = net debtor
  const netBalance = new Map<string, number>();

  for (const { fromUserId, toUserId, amount } of rawBalances) {
    if (amount <= 0) continue;

    // fromUserId owes toUserId `amount`. Round after each accumulation so
    // rounding dust from many expenses never drifts into a visible "phantom"
    // balance once debts are netted below.
    netBalance.set(
      fromUserId,
      Math.round(((netBalance.get(fromUserId) ?? 0) - amount) * 100) / 100
    );
    netBalance.set(
      toUserId,
      Math.round(((netBalance.get(toUserId) ?? 0) + amount) * 100) / 100
    );
  }

  // Separate into debtors (negative) and creditors (positive)
  const debtors: { userId: string; amount: number }[] = [];
  const creditors: { userId: string; amount: number }[] = [];

  for (const [userId, balance] of netBalance.entries()) {
    if (balance < -0.001) {
      debtors.push({ userId, amount: -balance });
    } else if (balance > 0.001) {
      creditors.push({ userId, amount: balance });
    }
  }

  const result: SimplifiedDebt[] = [];

  let di = 0;
  let ci = 0;

  while (di < debtors.length && ci < creditors.length) {
    const debtor = debtors[di];
    const creditor = creditors[ci];

    const settledAmount = Math.min(debtor.amount, creditor.amount);
    const rounded = Math.round(settledAmount * 100) / 100;

    if (rounded > 0.001) {
      result.push({
        fromUserId: debtor.userId,
        toUserId: creditor.userId,
        amount: rounded,
      });
    }

    debtor.amount -= settledAmount;
    creditor.amount -= settledAmount;

    if (debtor.amount < 0.001) di++;
    if (creditor.amount < 0.001) ci++;
  }

  return result;
}

export interface ExpenseData {
  id: string;
  amount: number;
  paidById: string;
  participants: { userId: string; share: number }[];
}

export interface SettlementData {
  payerId: string;
  payeeId: string;
  amount: number;
}

/**
 * Calculates net balances for a group from expenses and settlements.
 * Returns raw balance entries (who owes whom).
 */
export function calculateNetBalances(
  expenses: ExpenseData[],
  settlements: SettlementData[]
): RawBalance[] {
  const rawBalances: RawBalance[] = [];

  // For each expense, each participant owes the payer their share
  for (const expense of expenses) {
    for (const participant of expense.participants) {
      // Skip if participant is the payer (they don't owe themselves)
      if (participant.userId === expense.paidById) continue;

      rawBalances.push({
        fromUserId: participant.userId,
        toUserId: expense.paidById,
        amount: participant.share,
      });
    }
  }

  // Settlements reduce debts (negative balances)
  for (const settlement of settlements) {
    rawBalances.push({
      fromUserId: settlement.payeeId,
      toUserId: settlement.payerId,
      amount: settlement.amount,
    });
  }

  return rawBalances;
}
