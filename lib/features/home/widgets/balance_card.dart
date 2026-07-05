import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../add_transaction/add_transaction_sheet.dart';

class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  void _openSheet(BuildContext context, TransactionType initialType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(initialType: initialType),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final income = ref.watch(totalIncomeProvider);
    final expense = ref.watch(totalExpenseProvider);
    final balance = ref.watch(balanceProvider);
    final prevExpense = ref.watch(previousMonthExpenseProvider);
    final currency = ref.watch(currencyProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: isDark ? 0.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isDark ? 24 : 20,
            offset: Offset(0, isDark ? 12 : 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openSheet(context, TransactionType.expense),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Balance',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.primary.withValues(alpha: 0.8)
                                : AppColors.textLightSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        _MonthSelector(selectedMonth: selectedMonth),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TweenAnimationBuilder<double>(
                      duration: 1200.ms,
                      tween: Tween(begin: 0, end: balance),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        CurrencyFormatter.format(value, symbol: currency),
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textLight,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MoMDelta(
                      current: expense,
                      previous: prevExpense,
                      currency: currency,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 0.5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppColors.lightBorder,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openSheet(
                                  context, TransactionType.income),
                              child: _MiniStat(
                                label: 'Income',
                                amount: income,
                                currency: currency,
                                icon: Icons.arrow_downward_rounded,
                                color: AppColors.income,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 0.5,
                          height: 40,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : AppColors.lightBorder,
                        ),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openSheet(
                                  context, TransactionType.expense),
                              child: _MiniStat(
                                label: 'Expenses',
                                amount: expense,
                                currency: currency,
                                icon: Icons.arrow_upward_rounded,
                                color: AppColors.expense,
                                alignRight: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(
        begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }
}

class _MonthSelector extends ConsumerWidget {
  final DateTime selectedMonth;
  const _MonthSelector({required this.selectedMonth});

  bool get _isCurrent {
    final now = DateTime.now();
    return now.year == selectedMonth.year && now.month == selectedMonth.month;
  }

  void _shift(WidgetRef ref, int delta) {
    final notifier = ref.read(selectedMonthProvider.notifier);
    final cur = notifier.state;
    notifier.state = DateTime(cur.year, cur.month + delta);
  }

  bool _canGoForward() {
    final now = DateTime.now();
    return selectedMonth.year < now.year ||
        (selectedMonth.year == now.year && selectedMonth.month < now.month);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canForward = _canGoForward();
    final label = _isCurrent
        ? 'This Month'
        : DateFormat('MMM yyyy').format(selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkResponse(
            radius: 16,
            onTap: () => _shift(ref, -1),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.chevron_left_rounded,
                  size: 16, color: AppColors.primary),
            ),
          ),
          GestureDetector(
            onTap: () => _openMonthPicker(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          InkResponse(
            radius: 16,
            onTap: canForward ? () => _shift(ref, 1) : null,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: canForward
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMonthPicker(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(now.year - 5, 1),
      lastDate: DateTime(now.year, now.month),
      initialDatePickerMode: DatePickerMode.year,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(selectedMonthProvider.notifier).state =
          DateTime(picked.year, picked.month);
    }
  }
}

class _MoMDelta extends StatelessWidget {
  final double current;
  final double previous;
  final String currency;

  const _MoMDelta({
    required this.current,
    required this.previous,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (previous <= 0 && current <= 0) {
      return const SizedBox(height: 18);
    }
    final delta = current - previous;
    final hasPrev = previous > 0;
    final pct = hasPrev ? (delta.abs() / previous) * 100 : 0.0;
    final isUp = delta > 0;
    final color = isUp ? AppColors.expense : AppColors.income;

    return Row(
      children: [
        Icon(
          isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          hasPrev
              ? '${pct.toStringAsFixed(0)}% ${isUp ? 'higher' : 'lower'} than last month'
              : 'No spend last month',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final IconData icon;
  final Color color;
  final bool alignRight;

  const _MiniStat({
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: alignRight ? 16 : 0,
        right: alignRight ? 0 : 16,
      ),
      child: Row(
        mainAxisAlignment:
            alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!alignRight) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 10),
          ],
          Column(
            crossAxisAlignment:
                alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Builder(builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textLightSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.format(amount, symbol: currency),
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (alignRight) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
          ],
        ],
      ),
    );
  }
}
