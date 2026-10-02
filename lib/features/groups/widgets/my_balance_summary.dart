import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/balance_model.dart';
import '../../../data/models/group_expense_model.dart';
import '../../../data/models/group_model.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';

class MyBalanceSummary extends ConsumerStatefulWidget {
  const MyBalanceSummary({super.key});

  @override
  ConsumerState<MyBalanceSummary> createState() => _MyBalanceSummaryState();
}

class _MyBalanceSummaryState extends ConsumerState<MyBalanceSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final groups = ref.watch(groupsProvider).valueOrNull ?? [];
    final currency = ref.watch(currencyProvider);
    final balances = <String, AsyncValue<GroupBalanceSummary>>{};
    final expenses = <String, AsyncValue<List<GroupExpenseModel>>>{};
    var hasError = false;
    var isLoading = false;

    for (final group in groups) {
      final groupBalances = ref.watch(groupBalancesProvider(group.id));
      final groupExpenses = ref.watch(groupExpensesProvider(group.id));
      balances[group.id] = groupBalances;
      expenses[group.id] = groupExpenses;
      hasError |= groupBalances.hasError || groupExpenses.hasError;
      isLoading |= groupBalances.isLoading || groupExpenses.isLoading;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardTheme.color ?? AppColors.darkCard;
    final cardBackground = isDark ? cardColor : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (hasError) {
      return _DashboardCard(
        isDark: isDark,
        background: cardBackground,
        child: Row(
          children: [
            const Expanded(
              child: Text(
                "Couldn't load your group overview.",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => _retry(ref, groups),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return _DashboardCard(
        isDark: isDark,
        background: cardBackground,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    var totalOwed = 0.0;
    var totalLent = 0.0;
    var totalSpent = 0.0;
    var monthSpent = 0.0;
    final groupNames = {for (final group in groups) group.id: group.name};
    final allExpenses = <GroupExpenseModel>[];
    final now = DateTime.now();

    for (final group in groups) {
      final groupBalance = balances[group.id]?.valueOrNull;
      if (groupBalance != null) {
        totalOwed += groupBalance.totalOwed;
        totalLent += groupBalance.totalLent;
      }

      final groupExpenses = expenses[group.id]?.valueOrNull ?? [];
      for (final expense in groupExpenses) {
        totalSpent += expense.amount;
        if (expense.date.year == now.year && expense.date.month == now.month) {
          monthSpent += expense.amount;
        }
      }
      allExpenses.addAll(groupExpenses);
    }

    allExpenses.sort((a, b) => b.date.compareTo(a.date));
    final recentExpenses = allExpenses.take(4).toList();
    final net = totalLent - totalOwed;
    final isPositive = net >= 0;
    const zeroThreshold = 0.005;
    if (totalOwed.abs() < zeroThreshold &&
        totalLent.abs() < zeroThreshold &&
        totalSpent.abs() < zeroThreshold &&
        monthSpent.abs() < zeroThreshold) {
      return const SizedBox.shrink();
    }

    return _DashboardCard(
      isDark: isDark,
      background: cardBackground,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your overview',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${groups.length} ${groups.length == 1 ? 'group' : 'groups'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CompactSpendMetric(
                  label: 'Total spent',
                  amount: totalSpent,
                  currency: currency,
                  color: primary,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 44,
                color: borderColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CompactSpendMetric(
                  label: 'This month',
                  amount: monthSpent,
                  currency: currency,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: borderColor),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Net balance',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _NetBalanceChip(
                  value: net,
                  currency: currency,
                  positive: isPositive,
                  primary: primary,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _BalanceValue(
                              label: "You're owed",
                              value: totalLent,
                              currency: currency,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 1,
                            height: 44,
                            color: borderColor,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _BalanceValue(
                              label: 'You owe',
                              value: totalOwed,
                              currency: currency,
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                      if (recentExpenses.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Divider(height: 1, color: borderColor),
                        const SizedBox(height: 10),
                        Text(
                          'Recent expenses',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final expense in recentExpenses)
                          _RecentExpenseRow(
                            expense: expense,
                            groupName: groupNames[expense.groupId] ?? 'Group',
                            currency: currency,
                            onTap: () =>
                                context.push('/groups/${expense.groupId}'),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _retry(WidgetRef ref, List<GroupModel> groups) {
    for (final group in groups) {
      ref.invalidate(groupBalancesProvider(group.id));
      ref.invalidate(groupExpensesProvider(group.id));
    }
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.isDark,
    required this.background,
    required this.child,
    this.onTap,
  });

  final bool isDark;
  final Color background;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: ShapeDecoration(
        color: background,
        shape: shape,
        shadows: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _CompactSpendMetric extends StatelessWidget {
  const _CompactSpendMetric({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.formatCompact(amount, symbol: currency),
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _NetBalanceChip extends StatelessWidget {
  const _NetBalanceChip({
    required this.value,
    required this.currency,
    required this.positive,
    required this.primary,
  });

  final double value;
  final String currency;
  final bool positive;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final color = value.abs() < 0.01
        ? AppColors.textTertiary
        : positive
            ? primary
            : AppColors.expense;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value.abs() < 0.01
              ? 'Settled'
              : '${positive ? '+' : '-'}${CurrencyFormatter.formatAmountWithCommas(value.abs(), symbol: currency, decimalDigits: 0)}',
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BalanceValue extends StatelessWidget {
  const _BalanceValue({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
  });

  final String label;
  final double value;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final formatted =
        CurrencyFormatter.formatAmountWithCommas(value, symbol: currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatted,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentExpenseRow extends StatelessWidget {
  const _RecentExpenseRow({
    required this.expense,
    required this.groupName,
    required this.currency,
    required this.onTap,
  });

  final GroupExpenseModel expense;
  final String groupName;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 17,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              expense.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    isDark ? Colors.white : AppColors.textLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  CurrencyFormatter.formatAmountWithCommas(
                                    expense.amount,
                                    symbol: currency,
                                  ),
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textLight,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$groupName · ${expense.paidByName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('MMM d').format(expense.date),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
