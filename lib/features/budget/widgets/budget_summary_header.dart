import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';

/// Total Budget summary — styled to match the home screen's [BalanceCard]
/// (same radius, border, shadow and typography) so the app's two "hero"
/// numbers feel like one family.
class BudgetSummaryHeader extends ConsumerWidget {
  const BudgetSummaryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(budgetSummaryProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    if (summary.activeBudgets == 0) return const SizedBox.shrink();

    final overallProgress = summary.totalBudget > 0
        ? (summary.totalSpent / summary.totalBudget).clamp(0.0, 1.0)
        : 0.0;

    final overallColor = summary.totalSpent > summary.totalBudget
        ? AppColors.expense
        : overallProgress >= 0.8
            ? AppColors.warning
            : primary;

    final dividerColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? cardBg : Colors.white,
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/budget/overview'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Budget',
                        style: TextStyle(
                          color: isDark
                              ? primary.withValues(alpha: 0.8)
                              : AppColors.textLightSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          _StatusBadge(
                            label: '${summary.activeBudgets} active',
                            color: primary,
                            icon: Icons.check_circle_rounded,
                          ),
                          if (summary.overspentBudgets > 0) ...[
                            const SizedBox(width: 6),
                            _StatusBadge(
                              label: '${summary.overspentBudgets} over',
                              color: AppColors.expense,
                              icon: Icons.warning_rounded,
                            ),
                          ],
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppColors.textTertiary),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(summary.totalBudget,
                            symbol: currency),
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textLight,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${(overallProgress * 100).toStringAsFixed(0)}% used',
                          style: TextStyle(
                            color: overallColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      minHeight: 5,
                      backgroundColor: overallColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(overallColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(height: 0.5, color: dividerColor),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          label: 'Spent',
                          amount: summary.totalSpent,
                          currency: currency,
                          icon: Icons.arrow_upward_rounded,
                          color: AppColors.expense,
                        ),
                      ),
                      Container(width: 0.5, height: 36, color: dividerColor),
                      Expanded(
                        child: _MiniStat(
                          label: 'Remaining',
                          amount: summary.totalRemaining,
                          currency: currency,
                          icon: Icons.arrow_downward_rounded,
                          color: primary,
                          alignRight: true,
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
    );
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

// ── Mirrors BalanceCard's _MiniStat so Spent/Remaining reads the same way
// as Income/Expenses does on the home screen ──
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textLightSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
