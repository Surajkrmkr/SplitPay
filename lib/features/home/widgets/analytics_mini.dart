import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';

/// Compact weekly-spending bar + top-category row shown on the home screen.
/// Tapping "Full report →" navigates to the standalone analytics screen.
class AnalyticsMini extends ConsumerWidget {
  const AnalyticsMini({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklySpendingProvider);
    final breakdown = ref.watch(categoryBreakdownProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final weekTotal = weekly.fold(0.0, (a, b) => a + b);
    if (weekTotal == 0 && breakdown.isEmpty) return const SizedBox.shrink();

    final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Insights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              GestureDetector(
                onTap: () => context.push('/analytics'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Full report',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Weekly mini bar chart ──
          if (weekTotal > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This week',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(weekTotal, symbol: currency),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _MiniBarChart(weekly: weekly, isDark: isDark),
          ],

          // ── Top 3 categories ──
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 14),
            _TopCategories(
              breakdown: breakdown,
              currency: currency,
              isDark: isDark,
            ),
          ],
        ],
      ),
    ).animate(delay: 450.ms).fadeIn(duration: 400.ms).slideY(begin: 0.15);
  }
}

// ── Mini 7-day bar chart using plain containers ───────────────────────────────

class _MiniBarChart extends StatelessWidget {
  final List<double> weekly;
  final bool isDark;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  const _MiniBarChart({required this.weekly, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        weekly.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);
    final todayIndex = DateTime.now().weekday - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final ratio = weekly[i] / maxVal;
        final isToday = i == todayIndex;
        final color = isToday
            ? AppColors.primary
            : AppColors.secondary.withValues(alpha: 0.45);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: 700.ms,
                  tween: Tween(begin: 0, end: ratio),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Container(
                    height: 48 * v + 4,
                    decoration: BoxDecoration(
                      color: weekly[i] == 0
                          ? (isDark
                              ? AppColors.darkElevated
                              : AppColors.lightCard)
                          : color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _days[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w400,
                    color:
                        isToday ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Top 3 categories as compact rows ─────────────────────────────────────────

class _TopCategories extends StatelessWidget {
  final Map<Category, double> breakdown;
  final String currency;
  final bool isDark;

  const _TopCategories({
    required this.breakdown,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    final top = sorted.take(3).toList();

    return Column(
      children: top.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final cat = item.key;
        final pct = total > 0 ? item.value / total : 0.0;
        final color = cat.color;

        return Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(cat.icon, color: color, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppColors.textLight,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(item.value,
                              symbol: currency),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        duration: 800.ms,
                        tween: Tween(begin: 0, end: pct),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 4,
                          backgroundColor:
                              color.withValues(alpha: 0.1),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
