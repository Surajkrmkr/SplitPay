import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/token_storage.dart';
import '../data/models/budget_model.dart';
import '../data/models/transaction_model.dart';
import '../data/repositories/budget_repository.dart';
import 'transaction_provider.dart';

// ─── Core budget list ────────────────────────────────────────────────────────

final budgetProvider = StateNotifierProvider<BudgetNotifier, List<Budget>>(
  (ref) {
    final notifier = BudgetNotifier(ref.watch(budgetRepositoryProvider));
    Future.microtask(() async {
      // See transaction_provider.dart — skip the auto-fetch when logged out
      // so an eager rebuild from logout/session-expiry cleanup can't fire it.
      if (await ref.read(tokenStorageProvider).hasTokens()) {
        await notifier.load();
      }
    });
    return notifier;
  },
);

class BudgetNotifier extends StateNotifier<List<Budget>> {
  final BudgetRepository _repo;

  BudgetNotifier(this._repo) : super([]);

  Future<void> load() async {
    try {
      state = await _repo.getAll();
    } catch (_) {}
  }

  Future<void> add(Budget budget) async {
    state = [budget, ...state]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    try {
      await _repo.create(budget);
    } finally {
      await load();
    }
  }

  Future<void> update(Budget budget) async {
    state = state.map((b) => b.id == budget.id ? budget : b).toList();
    try {
      await _repo.update(budget);
    } finally {
      await load();
    }
  }

  Future<void> delete(String id) async {
    state = state.where((b) => b.id != id).toList();
    try {
      await _repo.delete(id);
    } finally {
      await load();
    }
  }

  Future<void> archive(String id) async {
    final b = state.firstWhere((b) => b.id == id);
    await update(b.copyWith(isArchived: true, updatedAt: DateTime.now()));
  }

  Future<void> unarchive(String id) async {
    final b = state.firstWhere((b) => b.id == id);
    await update(b.copyWith(isArchived: false, updatedAt: DateTime.now()));
  }
}

// ─── UI filter state ─────────────────────────────────────────────────────────

enum BudgetPeriodFilter { all, daily, weekly, monthly, yearly }

final budgetPeriodFilterProvider =
    StateProvider<BudgetPeriodFilter>((_) => BudgetPeriodFilter.all);

final showArchivedBudgetsProvider = StateProvider<bool>((_) => false);

final budgetSearchQueryProvider = StateProvider<String>((_) => '');

// ─── Derived budget lists ────────────────────────────────────────────────────

final activeBudgetsProvider = Provider<List<Budget>>((ref) =>
    ref.watch(budgetProvider).where((b) => !b.isArchived).toList());

final filteredBudgetsProvider = Provider<List<Budget>>((ref) {
  final budgets = ref.watch(budgetProvider);
  final periodFilter = ref.watch(budgetPeriodFilterProvider);
  final showArchived = ref.watch(showArchivedBudgetsProvider);
  final query = ref.watch(budgetSearchQueryProvider).toLowerCase().trim();

  return budgets.where((b) {
    if (b.isArchived != showArchived) return false;
    if (periodFilter != BudgetPeriodFilter.all) {
      final match = switch (periodFilter) {
        BudgetPeriodFilter.daily => BudgetPeriod.daily,
        BudgetPeriodFilter.weekly => BudgetPeriod.weekly,
        BudgetPeriodFilter.monthly => BudgetPeriod.monthly,
        BudgetPeriodFilter.yearly => BudgetPeriod.yearly,
        BudgetPeriodFilter.all => null,
      };
      if (match != null && b.period != match) return false;
    }
    if (query.isNotEmpty && !b.title.toLowerCase().contains(query)) return false;
    return true;
  }).toList();
});

// ─── Per-budget computed values ──────────────────────────────────────────────

/// Amount spent against a specific budget in the budget's current period.
final budgetSpentProvider = Provider.family<double, String>((ref, budgetId) {
  final budget = ref
      .watch(budgetProvider)
      .cast<Budget?>()
      .firstWhere((b) => b?.id == budgetId, orElse: () => null);
  if (budget == null) return 0.0;

  final range = budget.period.currentRange;
  final transactions = ref.watch(transactionProvider);

  return transactions
      .where((tx) {
        if (tx.type != TransactionType.expense) return false;
        if (tx.date.isBefore(range.start) || tx.date.isAfter(range.end)) {
          return false;
        }
        if (budget.isGlobal) return true;
        if (tx.customCategoryId == null) {
          return budget.categoryIds.contains(tx.category.name);
        }
        return budget.categoryIds.contains(tx.customCategoryId);
      })
      .fold(0.0, (sum, tx) => sum + tx.amount);
});

/// Spending ratio (0.0–unbounded; >1.0 means overspent).
final budgetProgressProvider =
    Provider.family<double, String>((ref, budgetId) {
  final budget = ref
      .watch(budgetProvider)
      .cast<Budget?>()
      .firstWhere((b) => b?.id == budgetId, orElse: () => null);
  if (budget == null || budget.amount <= 0) return 0.0;
  return ref.watch(budgetSpentProvider(budgetId)) / budget.amount;
});

/// Color-coded status for a budget.
final budgetStatusProvider =
    Provider.family<BudgetStatus, String>((ref, budgetId) {
  final progress = ref.watch(budgetProgressProvider(budgetId));
  final budget = ref
      .watch(budgetProvider)
      .cast<Budget?>()
      .firstWhere((b) => b?.id == budgetId, orElse: () => null);
  if (budget == null) return BudgetStatus.safe;
  if (progress >= 1.0) return BudgetStatus.exceeded;
  if (progress >= budget.alertThreshold) return BudgetStatus.warning;
  return BudgetStatus.safe;
});

/// Transactions that belong to a specific budget in its current period.
final budgetTransactionsProvider =
    Provider.family<List<Transaction>, String>((ref, budgetId) {
  final budget = ref
      .watch(budgetProvider)
      .cast<Budget?>()
      .firstWhere((b) => b?.id == budgetId, orElse: () => null);
  if (budget == null) return [];

  final range = budget.period.currentRange;
  return ref.watch(transactionProvider).where((tx) {
    if (tx.type != TransactionType.expense) return false;
    if (tx.date.isBefore(range.start) || tx.date.isAfter(range.end)) {
      return false;
    }
    if (budget.isGlobal) return true;
    if (tx.customCategoryId == null) {
      return budget.categoryIds.contains(tx.category.name);
    }
    return budget.categoryIds.contains(tx.customCategoryId);
  }).toList();
});

// ─── Dashboard aggregate summary ─────────────────────────────────────────────

typedef BudgetSummary = ({
  double totalBudget,
  double totalSpent,
  double totalRemaining,
  int activeBudgets,
  int overspentBudgets,
});

final budgetSummaryProvider = Provider<BudgetSummary>((ref) {
  final budgets = ref.watch(activeBudgetsProvider);

  double totalBudget = 0;
  double totalSpent = 0;
  int overspent = 0;

  for (final b in budgets) {
    totalBudget += b.amount;
    final spent = ref.watch(budgetSpentProvider(b.id));
    totalSpent += spent;
    if (spent > b.amount) overspent++;
  }

  return (
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    totalRemaining: (totalBudget - totalSpent).clamp(0.0, double.infinity),
    activeBudgets: budgets.length,
    overspentBudgets: overspent,
  );
});
