import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/services/home_widget_service.dart';
import '../data/models/transaction_model.dart';
import 'budget_provider.dart';
import 'settings_provider.dart' show currencyProvider;
import 'theme_provider.dart';
import 'transaction_provider.dart';

/// Recomputes and pushes all home-screen widget data (Overall Budget, Recent
/// Transactions, Insights) whenever balances, transactions, budgets, or the
/// currency change.
///
/// Watched by [recentTransactionsProvider] (so opening the home screen
/// refreshes the widgets) and by the budget screens (so editing a budget
/// does too).
final homeWidgetSyncProvider = Provider<void>((ref) {
  final balance = ref.watch(balanceProvider);
  final income = ref.watch(totalIncomeProvider);
  final expense = ref.watch(totalExpenseProvider);
  final currency = ref.watch(currencyProvider);
  final txs = ref.watch(transactionProvider);
  final pending = ref.watch(pendingDeletesProvider);
  final recents = txs.where((t) => !pending.contains(t.id)).take(5).toList();

  // Overall Budget — sum of all active (non-archived) budgets, regardless of
  // each budget's own period, labelled with the current calendar month.
  final summary = ref.watch(budgetSummaryProvider);
  final hasBudgetData = summary.activeBudgets > 0;
  final now = DateTime.now();
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  final periodLabel = '1 - $lastDay ${_monthAbbrev[now.month - 1]}';

  // Recent Transactions widget — net income vs. expense this week, Sunday
  // through today.
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday % 7));
  double netThisWeek = 0;
  for (final tx in txs) {
    final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
    if (txDate.isBefore(weekStart) || txDate.isAfter(today)) continue;
    netThisWeek += tx.type == TransactionType.income ? tx.amount : -tx.amount;
  }

  // Insights widget — this month's expenses, bucketed into 5 ~weekly chunks
  // (days 1-7, 8-14, 15-21, 22-28, 29-31), up through today.
  final monthBucketAmounts = List<double>.filled(5, 0.0);
  for (final tx in txs) {
    if (tx.type != TransactionType.expense) continue;
    final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
    if (txDate.year != now.year || txDate.month != now.month) continue;
    if (txDate.isAfter(today)) continue;
    final bucket = ((txDate.day - 1) ~/ 7).clamp(0, 4);
    monthBucketAmounts[bucket] += tx.amount;
  }

  final accentColor = ref.watch(themeProvider).preset.primaryColor;

  HomeWidgetService.updateWidgetData(
    balance: balance,
    totalIncome: income,
    totalExpense: expense,
    currency: currency,
    recentTransactions: recents,
    hasBudgetData: hasBudgetData,
    budgetPeriodLabel: periodLabel,
    budgetSpent: summary.totalSpent,
    budgetLimit: summary.totalBudget,
    monthBucketAmounts: monthBucketAmounts,
    netThisWeek: netThisWeek,
    accentColor: accentColor,
  );
});

const _monthAbbrev = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];
