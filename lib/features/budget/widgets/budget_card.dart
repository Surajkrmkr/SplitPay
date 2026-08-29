import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/budget_model.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';

class BudgetCard extends ConsumerWidget {
  final Budget budget;
  final VoidCallback? onTap;

  /// Compact layout for use inside a grid (2-up), stacking everything
  /// vertically instead of the wider list-row layout.
  final bool compact;

  const BudgetCard({
    super.key,
    required this.budget,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spent = ref.watch(budgetSpentProvider(budget.id));
    final progress = ref.watch(budgetProgressProvider(budget.id));
    final status = ref.watch(budgetStatusProvider(budget.id));
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    final remaining = (budget.amount - spent).clamp(0.0, double.infinity);
    final overspent = spent > budget.amount ? spent - budget.amount : 0.0;
    final pct = (progress * 100).clamp(0.0, 999.0);

    final statusColor = switch (status) {
      BudgetStatus.safe => primary,
      BudgetStatus.warning => AppColors.warning,
      BudgetStatus.exceeded => AppColors.expense,
    };

    final cardDecoration = BoxDecoration(
      color: isDark ? cardBg : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(compact ? 18 : 20),
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        width: 1,
      ),
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        margin: compact ? null : const EdgeInsets.symmetric(horizontal: 20),
        decoration: cardDecoration,
        child: compact
            ? _CompactBody(
                budget: budget,
                spent: spent,
                progress: progress,
                pct: pct,
                remaining: remaining,
                overspent: overspent,
                status: status,
                statusColor: statusColor,
                currency: currency,
                isDark: isDark,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Colored accent header ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: budget.color.withValues(alpha: 0.12),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: budget.color.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(budget.icon,
                              color: budget.color, size: 18),
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
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              _CategoryChips(budget: budget, isDark: isDark),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PeriodBadge(
                            period: budget.period, color: budget.color),
                      ],
                    ),
                  ),

                  // ── Body ──
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrencyFormatter.format(spent,
                                      symbol: currency),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'of ${CurrencyFormatter.format(budget.amount, symbol: currency)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            _PctBadge(pct: pct, status: status),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor:
                                statusColor.withValues(alpha: 0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Bottom info row
                        Row(
                          children: [
                            Icon(
                              status == BudgetStatus.exceeded
                                  ? Icons.warning_rounded
                                  : Icons.info_outline_rounded,
                              size: 13,
                              color: statusColor,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                status == BudgetStatus.exceeded
                                    ? '${CurrencyFormatter.format(overspent, symbol: currency)} overspent'
                                    : '${CurrencyFormatter.format(remaining, symbol: currency)} remaining',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              budget.period.nextResetLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
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
    );
  }
}

// ── Compact grid-cell body ───────────────────────────────────────────────────

class _CompactBody extends StatelessWidget {
  final Budget budget;
  final double spent;
  final double progress;
  final double pct;
  final double remaining;
  final double overspent;
  final BudgetStatus status;
  final Color statusColor;
  final String currency;
  final bool isDark;

  const _CompactBody({
    required this.budget,
    required this.spent,
    required this.progress,
    required this.pct,
    required this.remaining,
    required this.overspent,
    required this.status,
    required this.statusColor,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: budget.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(budget.icon, color: budget.color, size: 16),
              ),
              const Spacer(),
              _PctBadge(pct: pct, status: status, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            budget.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          _CategoryChips(budget: budget, isDark: isDark),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(spent, symbol: currency),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: statusColor,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'of ${CurrencyFormatter.format(budget.amount, symbol: currency)}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status == BudgetStatus.exceeded
                ? '${CurrencyFormatter.format(overspent, symbol: currency)} over'
                : '${CurrencyFormatter.format(remaining, symbol: currency)} left',
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Period badge chip ────────────────────────────────────────────────────────

class _PeriodBadge extends StatelessWidget {
  final BudgetPeriod period;
  final Color color;

  const _PeriodBadge({required this.period, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(period.periodIcon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            period.label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Percentage badge ─────────────────────────────────────────────────────────

class _PctBadge extends StatelessWidget {
  final double pct;
  final BudgetStatus status;
  final bool compact;

  const _PctBadge({required this.pct, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BudgetStatus.safe => AppColors.income,
      BudgetStatus.warning => AppColors.warning,
      BudgetStatus.exceeded => AppColors.expense,
    };

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${pct.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: compact ? 11 : 14,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ── Category chips row ───────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final Budget budget;
  final bool isDark;

  const _CategoryChips({required this.budget, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (budget.isGlobal) {
      return Text(
        'All expenses',
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final count = budget.categoryIds.length;
    return Text(
      '$count ${count == 1 ? 'category' : 'categories'}',
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
