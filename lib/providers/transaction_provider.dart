import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/transaction_model.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/services/hive_service.dart';

// All transactions, sorted by date desc — reads from Hive (offline-first).
final transactionProvider =
    StateNotifierProvider<TransactionNotifier, List<Transaction>>(
  (ref) => TransactionNotifier(ref.watch(transactionRepositoryProvider), ref)..load(),
);

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  final TransactionRepository _repo;
  final Ref _ref;

  TransactionNotifier(this._repo, this._ref) : super([]);

  void load() {
    state = _repo.getAll();
  }

  Future<void> add(Transaction tx) async {
    await _repo.add(tx);
    load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    load();
  }

  Future<void> update(Transaction tx) async {
    await _repo.update(tx);
    load();
  }

  /// Pull-to-refresh: full server sync then reload local state.
  Future<void> syncAndReload() async {
    final result = await _repo.syncNow();
    load();
    if (result.errorMessage == null) {
      await HiveService.setSetting(
        'lastSyncedAt',
        result.syncedAt.millisecondsSinceEpoch,
      );
      _ref.read(lastSyncedAtProvider.notifier).state = result.syncedAt;
    }
  }
}

// ─── Month selector ───────────────────────────────────────────────────────────

final selectedMonthProvider = StateProvider<DateTime>((_) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// ─── Computed summary providers ───────────────────────────────────────────────

final totalIncomeProvider = Provider<double>((ref) {
  final txs = ref.watch(transactionProvider);
  final month = ref.watch(selectedMonthProvider);
  return txs
      .where((t) =>
          t.type == TransactionType.income &&
          t.date.year == month.year &&
          t.date.month == month.month)
      .fold(0, (sum, t) => sum + t.amount);
});

final totalExpenseProvider = Provider<double>((ref) {
  final txs = ref.watch(transactionProvider);
  final month = ref.watch(selectedMonthProvider);
  return txs
      .where((t) =>
          t.type == TransactionType.expense &&
          t.date.year == month.year &&
          t.date.month == month.month)
      .fold(0, (sum, t) => sum + t.amount);
});

final balanceProvider = Provider<double>((ref) {
  final income = ref.watch(totalIncomeProvider);
  final expense = ref.watch(totalExpenseProvider);
  return income - expense;
});

final previousMonthExpenseProvider = Provider<double>((ref) {
  final txs = ref.watch(transactionProvider);
  final selected = ref.watch(selectedMonthProvider);
  final prev = DateTime(selected.year, selected.month - 1);
  return txs
      .where((t) =>
          t.type == TransactionType.expense &&
          t.date.year == prev.year &&
          t.date.month == prev.month)
      .fold(0, (sum, t) => sum + t.amount);
});

final previousMonthIncomeProvider = Provider<double>((ref) {
  final txs = ref.watch(transactionProvider);
  final selected = ref.watch(selectedMonthProvider);
  final prev = DateTime(selected.year, selected.month - 1);
  return txs
      .where((t) =>
          t.type == TransactionType.income &&
          t.date.year == prev.year &&
          t.date.month == prev.month)
      .fold(0, (sum, t) => sum + t.amount);
});

final recentTransactionsProvider = Provider<List<Transaction>>((ref) {
  return ref.watch(transactionProvider).take(5).toList();
});

final categoryBreakdownProvider = Provider<Map<Category, double>>((ref) {
  final txs = ref.watch(transactionProvider);
  final month = ref.watch(selectedMonthProvider);
  final expenses = txs.where((t) =>
      t.type == TransactionType.expense &&
      t.date.year == month.year &&
      t.date.month == month.month);

  final map = <Category, double>{};
  for (final tx in expenses) {
    map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
  }
  return map;
});

final weeklySpendingProvider = Provider<List<double>>((ref) {
  final txs = ref.watch(transactionProvider);
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));

  final days = List.filled(7, 0.0);
  for (final tx in txs) {
    if (tx.type == TransactionType.expense &&
        tx.date.isAfter(weekStart.subtract(const Duration(days: 1)))) {
      final dayIndex = tx.date.weekday - 1;
      if (dayIndex >= 0 && dayIndex < 7) {
        days[dayIndex] += tx.amount;
      }
    }
  }
  return days;
});

final monthlyTrendProvider = Provider<List<double>>((ref) {
  final txs = ref.watch(transactionProvider);
  final now = DateTime.now();

  final months = List.filled(6, 0.0);
  for (var i = 0; i < 6; i++) {
    final month = DateTime(now.year, now.month - (5 - i), 1);
    final total = txs
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == month.year &&
            t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.amount);
    months[i] = total;
  }
  return months;
});

final monthlyIncomeTrendProvider = Provider<List<double>>((ref) {
  final txs = ref.watch(transactionProvider);
  final now = DateTime.now();

  final months = List.filled(6, 0.0);
  for (var i = 0; i < 6; i++) {
    final month = DateTime(now.year, now.month - (5 - i), 1);
    final total = txs
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.year == month.year &&
            t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.amount);
    months[i] = total;
  }
  return months;
});

// ─── Filter / search providers ────────────────────────────────────────────────

enum TransactionFilter { all, today, week, month }

final filterProvider = StateProvider<TransactionFilter>(
  (_) => TransactionFilter.month,
);

final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final txs = ref.watch(transactionProvider);
  final filter = ref.watch(filterProvider);
  final now = DateTime.now();

  return switch (filter) {
    TransactionFilter.all => txs,
    TransactionFilter.today => txs.where((t) {
        return t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day;
      }).toList(),
    TransactionFilter.week => txs.where((t) {
        final weekAgo = now.subtract(const Duration(days: 7));
        return t.date.isAfter(weekAgo);
      }).toList(),
    TransactionFilter.month => txs.where((t) {
        return t.date.year == now.year && t.date.month == now.month;
      }).toList(),
  };
});

final searchQueryProvider = StateProvider<String>((_) => '');

final searchedTransactionsProvider = Provider<List<Transaction>>((ref) {
  final txs = ref.watch(filteredTransactionsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  if (query.isEmpty) return txs;

  return txs.where((t) {
    return t.category.label.toLowerCase().contains(query) ||
        (t.note?.toLowerCase().contains(query) ?? false);
  }).toList();
});
