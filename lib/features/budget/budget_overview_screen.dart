import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/budget_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/empty_state.dart';

/// Full breakdown behind the "Total Budget" card — the headline numbers at a
/// larger scale, the top 3 highest-spending budgets, and any budgets that
/// have gone over their limit. Flat, bordered surfaces throughout — no
/// gradients.
class BudgetOverviewScreen extends ConsumerWidget {
  const BudgetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(budgetSummaryProvider);
    final activeBudgets = ref.watch(activeBudgetsProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final overallProgress = summary.totalBudget > 0
        ? (summary.totalSpent / summary.totalBudget).clamp(0.0, 1.0)
        : 0.0;
    final overallColor = summary.totalSpent > summary.totalBudget
        ? AppColors.expense
        : overallProgress >= 0.8
            ? AppColors.warning
            : primary;

    // Rank every active budget by how much has been spent against it.
    final ranked = activeBudgets
        .map((b) => (budget: b, spent: ref.watch(budgetSpentProvider(b.id))))
        .toList()
      ..sort((a, b) => b.spent.compareTo(a.spent));

    final topSpenders = ranked.take(3).toList();
    final overLimit = ranked.where((r) => r.spent > r.budget.amount).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 12),
                    Text(
                      'Budget Overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            if (activeBudgets.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'No active budgets',
                  subtitle: 'Create a budget to see your overview here',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _TotalsCard(
                    totalBudget: summary.totalBudget,
                    totalSpent: summary.totalSpent,
                    totalRemaining: summary.totalRemaining,
                    progress: overallProgress,
                    color: overallColor,
                    currency: currency,
                    isDark: isDark,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Active',
                          value: '${summary.activeBudgets}',
                          icon: Icons.donut_small_rounded,
                          color: primary,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: 'Over limit',
                          value: '${summary.overspentBudgets}',
                          icon: Icons.warning_rounded,
                          color: AppColors.expense,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: 'Avg. used',
                          value: '${(overallProgress * 100).toStringAsFixed(0)}%',
                          icon: Icons.speed_rounded,
                          color: overallColor,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (topSpenders.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      'Top Spending',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final entry = topSpenders[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BudgetRow(
                            rank: i + 1,
                            budget: entry.budget,
                            spent: entry.spent,
                            currency: currency,
                            isDark: isDark,
                            onTap: () =>
                                context.push('/budget/${entry.budget.id}'),
                          ),
                        );
                      },
                      childCount: topSpenders.length,
                    ),
                  ),
                ),
              ],

              if (overLimit.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Over Limit',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${overLimit.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final entry = overLimit[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BudgetRow(
                            budget: entry.budget,
                            spent: entry.spent,
                            currency: currency,
                            isDark: isDark,
                            onTap: () =>
                                context.push('/budget/${entry.budget.id}'),
                          ),
                        );
                      },
                      childCount: overLimit.length,
                    ),
                  ),
                ),
              ],
            ],

            SliverToBoxAdapter(
              child: SizedBox(
                height: 24 + MediaQuery.of(context).padding.bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Totals card ──────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final double totalRemaining;
  final double progress;
  final Color color;
  final String currency;
  final bool isDark;

  const _TotalsCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRemaining,
    required this.progress,
    required this.color,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;
    final dividerColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? cardBg : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: isDark ? 0.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Budget',
            style: TextStyle(
              color: isDark
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                  : AppColors.textLightSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(totalBudget, symbol: currency),
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textLight,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% of budget used',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 0.5, color: dividerColor),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _AmountCell(
                  label: 'Spent',
                  amount: totalSpent,
                  currency: currency,
                  color: AppColors.expense,
                  isDark: isDark,
                ),
              ),
              Container(width: 0.5, height: 34, color: dividerColor),
              Expanded(
                child: _AmountCell(
                  label: 'Remaining',
                  amount: totalRemaining,
                  currency: currency,
                  color: Theme.of(context).colorScheme.primary,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;
  final bool isDark;

  const _AmountCell({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.textSecondary : AppColors.textLightSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.format(amount, symbol: currency),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Quick stat tile ──────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? cardBg : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textLight,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Budget row (used for both "Top Spending" and "Over Limit") ──────────────

class _BudgetRow extends StatelessWidget {
  final Budget budget;
  final double spent;
  final String currency;
  final bool isDark;
  final VoidCallback onTap;

  /// 1-based position when shown in the "Top Spending" list; null hides the
  /// rank badge (used for the "Over Limit" list).
  final int? rank;

  const _BudgetRow({
    required this.budget,
    required this.spent,
    required this.currency,
    required this.isDark,
    required this.onTap,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;
    final progress =
        budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
    final isOver = spent > budget.amount;
    final statusColor = isOver
        ? AppColors.expense
        : progress >= budget.alertThreshold
            ? AppColors.warning
            : budget.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? cardBg : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (rank != null) ...[
                    SizedBox(
                      width: 18,
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: budget.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(budget.icon, color: budget.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${CurrencyFormatter.format(spent, symbol: currency)} of ${CurrencyFormatter.format(budget.amount, symbol: currency)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (isOver)
                        Text(
                          '${CurrencyFormatter.format(spent - budget.amount, symbol: currency)} over',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
