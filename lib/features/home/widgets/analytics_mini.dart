import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';

class AnalyticsMini extends ConsumerWidget {
  const AnalyticsMini({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklySpendingProvider);
    final breakdown = ref.watch(categoryBreakdownProvider);
    final currency = ref.watch(currencyProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final weekTotal = weekly.fold(0.0, (a, b) => a + b);
    if (weekTotal == 0 && breakdown.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final isCurrent =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final monthLabel =
        isCurrent ? 'This month' : DateFormat('MMM yyyy').format(selectedMonth);

    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();

    final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

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
          // ── Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Insights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.push('/analytics'),
                    child: const Row(
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
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Weekly mini bar chart ──
          if (weekTotal > 0) ...[
            const SizedBox(height: 14),
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

          // ── Top categories grid ──
          if (top.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 14),
            const Text(
              'Top Categories',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 120,
              ),
              itemCount: top.length,
              itemBuilder: (context, i) {
                final entry = top[i];
                final pct = total > 0 ? entry.value / total : 0.0;
                return _CategoryCard(
                  category: entry.key,
                  amount: entry.value,
                  percentage: pct,
                  currency: currency,
                  isDark: isDark,
                ).animate(delay: (i * 80).ms).fadeIn().slideY(
                      begin: 0.2,
                      end: 0,
                      curve: Curves.easeOutCubic,
                    );
              },
            ),
          ],
        ],
      ),
    ).animate(delay: 450.ms).fadeIn(duration: 400.ms).slideY(begin: 0.15);
  }
}

// ── Mini 7-day bar chart ──────────────────────────────────────────────────────

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
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
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

// ── Category card (2×2 grid item) ────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final Category category;
  final double amount;
  final double percentage;
  final String currency;
  final bool isDark;

  const _CategoryCard({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final bgColor = isDark ? AppColors.darkElevated : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(category.icon, color: color, size: 15),
              ),
              Text(
                '${(percentage * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.label,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textLightSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                CurrencyFormatter.format(amount, symbol: currency),
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  duration: 800.ms,
                  tween: Tween(begin: 0, end: percentage),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
