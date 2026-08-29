import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/token_storage.dart';
import '../data/models/transaction_model.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/services/transaction_api_service.dart' show ImportResult;
import 'home_widget_sync_provider.dart' show homeWidgetSyncProvider;

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, List<Transaction>>(
  (ref) {
    final notifier =
        TransactionNotifier(ref.watch(transactionRepositoryProvider));
    Future.microtask(() async {
      // Providers get invalidated (and, if still watched by a kept-alive tab,
      // eagerly rebuilt) as part of logout/session-expiry cleanup. Skip the
      // fetch when there's no token so that doesn't fire a doomed API call.
      if (await ref.read(tokenStorageProvider).hasTokens()) {
        await notifier.load();
      }
    });
    return notifier;
  },
);

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  final TransactionRepository _repo;

  TransactionNotifier(this._repo) : super([]);

  Future<void> load() async {
    try {
      state = await _repo.getAll();
    } catch (_) {}
  }

  // Applies the change to local state immediately so dependent providers
  // (graphs, recents) reflect it without waiting on the network round-trip,
  // then reconciles with the server's copy once the request settles.
  Future<void> add(Transaction tx) async {
    state = [tx, ...state];
    try {
      await _repo.create(tx);
    } finally {
      await load();
    }
  }

  Future<void> delete(Transaction tx) async {
    state = state.where((t) => t.id != tx.id).toList();
    try {
      await _repo.delete(tx);
    } finally {
      await load();
    }
  }

  Future<void> update(Transaction tx) async {
    state = [for (final t in state) t.id == tx.id ? tx : t];
    try {
      await _repo.update(tx);
    } finally {
      await load();
    }
  }

  /// Pull-to-refresh: reload from server.
  Future<void> syncAndReload() => load();

  /// Replaces all existing personal transactions with [transactions] (e.g.
  /// from a CSV import) and reloads state from the server afterwards.
  Future<ImportResult> importAll(List<Transaction> transactions) async {
    final result = await _repo.importAll(transactions);
    await load();
    return result;
  }
}

// ─── Swipe-to-delete undo ──────────────────────────────────────────────────────
//
// Lives on this app-scoped provider — not on a page's State — so the pending
// delete's timer keeps running (and the transaction actually gets deleted)
// even if the user navigates away from the screen they swiped on before the
// undo window elapses.

class PendingDeletesNotifier extends Notifier<Set<String>> {
  final Map<String, Timer> _timers = {};

  @override
  Set<String> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
    });
    return {};
  }

  /// Hides [tx] immediately; commits the real delete after [undoWindow]
  /// unless [undo] is called first.
  void schedule(Transaction tx,
      {Duration undoWindow = const Duration(seconds: 3)}) {
    state = {...state, tx.id};
    _timers[tx.id]?.cancel();
    _timers[tx.id] = Timer(undoWindow, () {
      _timers.remove(tx.id);
      if (state.contains(tx.id)) {
        state = {...state}..remove(tx.id);
        ref.read(transactionProvider.notifier).delete(tx);
      }
    });
  }

  void undo(String id) {
    _timers.remove(id)?.cancel();
    state = {...state}..remove(id);
  }
}

final pendingDeletesProvider =
    NotifierProvider<PendingDeletesNotifier, Set<String>>(
  PendingDeletesNotifier.new,
);

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
  ref.watch(homeWidgetSyncProvider);
  final pending = ref.watch(pendingDeletesProvider);
  return ref
      .watch(transactionProvider)
      .where((t) => !pending.contains(t.id))
      .take(5)
      .toList();
});

// Keyed by the transaction's effective category — customCategoryId if set,
// otherwise the built-in Category's enum name — so custom-category spending
// is grouped under its own category instead of collapsing into "Other".
// Resolve a key's display info (label/icon/color) via [resolveCategoryDisplay].
final categoryBreakdownProvider = Provider<Map<String, double>>((ref) {
  final txs = ref.watch(transactionProvider);
  final month = ref.watch(selectedMonthProvider);
  final expenses = txs.where((t) =>
      t.type == TransactionType.expense &&
      t.date.year == month.year &&
      t.date.month == month.month);

  final map = <String, double>{};
  for (final tx in expenses) {
    final key = tx.customCategoryId ?? tx.category.name;
    map[key] = (map[key] ?? 0) + tx.amount;
  }
  return map;
});

final categoryBreakdownIncomeProvider = Provider<Map<String, double>>((ref) {
  final txs = ref.watch(transactionProvider);
  final month = ref.watch(selectedMonthProvider);
  final incomes = txs.where((t) =>
      t.type == TransactionType.income &&
      t.date.year == month.year &&
      t.date.month == month.month);

  final map = <String, double>{};
  for (final tx in incomes) {
    final key = tx.customCategoryId ?? tx.category.name;
    map[key] = (map[key] ?? 0) + tx.amount;
  }
  return map;
});

final weeklySpendingProvider = Provider<List<double>>((ref) {
  final txs = ref.watch(transactionProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));

  final days = List.filled(7, 0.0);
  for (final tx in txs) {
    if (tx.type != TransactionType.expense) continue;
    final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
    // From Monday of this week through today — a future-dated transaction
    // (even later this same week) hasn't been spent yet, so it shouldn't
    // count toward "this week"'s total.
    if (!txDate.isBefore(weekStart) && !txDate.isAfter(today)) {
      final dayIndex = txDate.weekday - 1;
      days[dayIndex] += tx.amount;
    }
  }
  return days;
});

final weeklyIncomeProvider = Provider<List<double>>((ref) {
  final txs = ref.watch(transactionProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));

  final days = List.filled(7, 0.0);
  for (final tx in txs) {
    if (tx.type != TransactionType.income) continue;
    final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
    if (!txDate.isBefore(weekStart) && !txDate.isAfter(today)) {
      final dayIndex = txDate.weekday - 1;
      days[dayIndex] += tx.amount;
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

enum TransactionTypeFilter { all, income, expense }

enum TransactionSortOrder {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount
}

// Amount range — null bounds mean no limit on that side.
class AmountRange {
  final double? min;
  final double? max;
  const AmountRange({this.min, this.max});
  bool get isActive => min != null || max != null;
}

final filterProvider = StateProvider<TransactionFilter>(
  (_) => TransactionFilter.month,
);

final transactionTypeFilterProvider =
    StateProvider<TransactionTypeFilter>((_) => TransactionTypeFilter.all);

final transactionSortProvider = StateProvider<TransactionSortOrder>(
    (_) => TransactionSortOrder.newestFirst);

// Set of category keys (Category.name or customCategoryId). Empty = all.
final categoryFilterProvider = StateProvider<Set<String>>((_) => const {});

final amountRangeProvider =
    StateProvider<AmountRange>((_) => const AmountRange());

final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final pending = ref.watch(pendingDeletesProvider);
  final txs = ref
      .watch(transactionProvider)
      .where((t) => !pending.contains(t.id))
      .toList();
  final filter = ref.watch(filterProvider);
  final typeFilter = ref.watch(transactionTypeFilterProvider);
  final sort = ref.watch(transactionSortProvider);
  final categories = ref.watch(categoryFilterProvider);
  final amountRange = ref.watch(amountRangeProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));

  var result = switch (filter) {
    TransactionFilter.all => txs,
    TransactionFilter.today => txs.where((t) {
        return t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day;
      }).toList(),
    // From Monday of this week through today — future-dated transactions
    // (even later this same week) are excluded, since "this week" means
    // what's happened so far, not what's scheduled.
    TransactionFilter.week => txs.where((t) {
        final txDate = DateTime(t.date.year, t.date.month, t.date.day);
        return !txDate.isBefore(weekStart) && !txDate.isAfter(today);
      }).toList(),
    // Unlike Week, Month shows the whole calendar month — including
    // future-dated entries later this month (e.g. an end-of-month salary).
    TransactionFilter.month => txs.where((t) {
        return t.date.year == now.year && t.date.month == now.month;
      }).toList(),
  };

  if (typeFilter == TransactionTypeFilter.income) {
    result = result.where((t) => t.type == TransactionType.income).toList();
  } else if (typeFilter == TransactionTypeFilter.expense) {
    result = result.where((t) => t.type == TransactionType.expense).toList();
  }

  if (categories.isNotEmpty) {
    result = result.where((t) {
      final key = t.customCategoryId ?? t.category.name;
      return categories.contains(key);
    }).toList();
  }

  if (amountRange.isActive) {
    result = result.where((t) {
      if (amountRange.min != null && t.amount < amountRange.min!) return false;
      if (amountRange.max != null && t.amount > amountRange.max!) return false;
      return true;
    }).toList();
  }

  result = List.from(result);
  switch (sort) {
    case TransactionSortOrder.newestFirst:
      result.sort((a, b) => b.date.compareTo(a.date));
    case TransactionSortOrder.oldestFirst:
      result.sort((a, b) => a.date.compareTo(b.date));
    case TransactionSortOrder.highestAmount:
      result.sort((a, b) => b.amount.compareTo(a.amount));
    case TransactionSortOrder.lowestAmount:
      result.sort((a, b) => a.amount.compareTo(b.amount));
  }

  return result;
});

// Count of active non-default filters (used for the badge on the filter button).
final activeFilterCountProvider = Provider<int>((ref) {
  int count = 0;
  if (ref.watch(transactionTypeFilterProvider) != TransactionTypeFilter.all)
    count++;
  if (ref.watch(transactionSortProvider) != TransactionSortOrder.newestFirst)
    count++;
  if (ref.watch(categoryFilterProvider).isNotEmpty) count++;
  if (ref.watch(amountRangeProvider).isActive) count++;
  return count;
});

// Recurring transactions — used by the notification settings screen.
final recurringTransactionsProvider = Provider<List<Transaction>>((ref) {
  return ref
      .watch(transactionProvider)
      .where((t) => t.recurrence.isRecurring)
      .toList();
});

// Max transaction amount across all transactions — used for the amount slider ceiling.
final maxTransactionAmountProvider = Provider<double>((ref) {
  final txs = ref.watch(transactionProvider);
  if (txs.isEmpty) return 50000.0;
  final max = txs.map((t) => t.amount).reduce((a, b) => a > b ? a : b);
  // Round up to the nearest 1000 for a clean slider max.
  return ((max / 1000).ceil() * 1000).toDouble().clamp(1000.0, 1000000.0);
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
