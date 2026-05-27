import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';

class BudgetSummaryHeader extends ConsumerWidget {
  const BudgetSummaryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(budgetSummaryProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (summary.activeBudgets == 0) return const SizedBox.shrink();

    final overallProgress = summary.totalBudget > 0
        ? (summary.totalSpent / summary.totalBudget).clamp(0.0, 1.0)
        : 0.0;

    final overallColor = summary.totalSpent > summary.totalBudget
        ? AppColors.expense
        : overallProgress >= 0.8
            ? AppColors.warning
            : AppColors.income;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            overallColor.withValues(alpha: 0.18),
            overallColor.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: overallColor.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Headline row ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Budget',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(summary.totalBudget,
                          symbol: currency),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textLight,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badges
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(
                    label: '${summary.activeBudgets} active',
                    color: AppColors.income,
                    icon: Icons.check_circle_rounded,
                  ),
                  if (summary.overspentBudgets > 0) ...[
                    const SizedBox(height: 6),
                    _StatusBadge(
                      label: '${summary.overspentBudgets} over limit',
                      color: AppColors.expense,
                      icon: Icons.warning_rounded,
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Overall progress bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              duration: 900.ms,
              tween: Tween(begin: 0, end: overallProgress),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: overallColor.withValues(alpha: 0.15),
                valueColor:
                    AlwaysStoppedAnimation<Color>(overallColor),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Stats row ──
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Spent',
                  value: CurrencyFormatter.format(summary.totalSpent,
                      symbol: currency),
                  color: AppColors.expense,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _StatCell(
                  label: 'Remaining',
                  value: CurrencyFormatter.format(
                      summary.totalRemaining,
                      symbol: currency),
                  color: AppColors.income,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _StatCell(
                  label: 'Used',
                  value:
                      '${(overallProgress * 100).toStringAsFixed(0)}%',
                  color: overallColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: 50.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
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

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 32,
      color: AppColors.textTertiary.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
