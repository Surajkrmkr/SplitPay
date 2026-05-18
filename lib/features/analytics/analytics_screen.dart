import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../shared/widgets/empty_state.dart';
import 'widgets/monthly_trend.dart';
import 'widgets/spending_pie_chart.dart';
import 'widgets/weekly_bar_chart.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);

    if (transactions.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'No data yet',
            subtitle:
                'Add your first transaction to see beautiful analytics here',
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _Header(),
                  const SizedBox(height: 20),
                  const _InsightsRow(),
                  const SizedBox(height: 20),
                  const SpendingPieChart(),
                  const SizedBox(height: 16),
                  const WeeklyBarChart(),
                  const SizedBox(height: 16),
                  const MonthlyTrendChart(),
                  const SizedBox(height: 16),
                  const _TopCategoryCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Analytics',
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _InsightsRow extends ConsumerWidget {
  const _InsightsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final income = ref.watch(totalIncomeProvider);
    final expense = ref.watch(totalExpenseProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = ref.watch(transactionProvider).length;

    final savingsRate =
        income > 0 ? ((income - expense) / income * 100).clamp(0.0, 100.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _InsightCard(
              label: 'Savings',
              value: '${savingsRate.toStringAsFixed(0)}%',
              icon: Icons.savings_rounded,
              color: AppColors.income,
              isDark: isDark,
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InsightCard(
              label: 'Avg/Day',
              value: CurrencyFormatter.format(
                expense > 0 ? expense / 30 : 0,
                symbol: currency,
              ),
              icon: Icons.today_rounded,
              color: AppColors.secondary,
              isDark: isDark,
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InsightCard(
              label: 'Total Txns',
              value: total.toString(),
              icon: Icons.receipt_long_rounded,
              color: AppColors.warning,
              isDark: isDark,
            ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.15),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _InsightCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textLight,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCategoryCard extends ConsumerWidget {
  const _TopCategoryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown = ref.watch(categoryBreakdownProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (breakdown.isEmpty) return const SizedBox.shrink();

    final topEntry =
        breakdown.entries.reduce((a, b) => a.value > b.value ? a : b);
    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    final pct = total > 0 ? topEntry.value / total * 100 : 0.0;
    final color = topEntry.key.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(topEntry.key.icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Spending',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textLightSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  topEntry.key.label,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}% of total',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(topEntry.value, symbol: currency),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.15);
  }
}
