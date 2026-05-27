import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/budget_model.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';

class BudgetCard extends ConsumerWidget {
  final Budget budget;
  final int animationIndex;
  final VoidCallback? onTap;

  const BudgetCard({
    super.key,
    required this.budget,
    this.animationIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spent = ref.watch(budgetSpentProvider(budget.id));
    final progress = ref.watch(budgetProgressProvider(budget.id));
    final status = ref.watch(budgetStatusProvider(budget.id));
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final remaining = (budget.amount - spent).clamp(0.0, double.infinity);
    final overspent = spent > budget.amount ? spent - budget.amount : 0.0;
    final pct = (progress * 100).clamp(0.0, 999.0);

    final statusColor = switch (status) {
      BudgetStatus.safe => AppColors.income,
      BudgetStatus.warning => AppColors.warning,
      BudgetStatus.exceeded => AppColors.expense,
    };

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: budget.color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
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
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      duration: 900.ms,
                      tween: Tween(
                          begin: 0,
                          end: progress.clamp(0.0, 1.0)),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor:
                            statusColor.withValues(alpha: 0.12),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(statusColor),
                      ),
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
    )
        .animate(delay: (animationIndex * 80).ms)
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
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

  const _PctBadge({required this.pct, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BudgetStatus.safe => AppColors.income,
      BudgetStatus.warning => AppColors.warning,
      BudgetStatus.exceeded => AppColors.expense,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${pct.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 14,
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
    );
  }
}
