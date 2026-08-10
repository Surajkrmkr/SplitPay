import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/legend_dot.dart';

class WeeklyBarChart extends ConsumerWidget {
  const WeeklyBarChart({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklySpendingProvider);
    final weeklyIncome = ref.watch(weeklyIncomeProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxVal = [...weekly, ...weeklyIncome].reduce((a, b) => a > b ? a : b);
    final chartMax = maxVal == 0 ? 100.0 : maxVal * 1.25;

    final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final gridColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final todayIndex = DateTime.now().weekday - 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Week',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Row(
                children: [
                  LegendDot(color: AppColors.income, label: 'Income'),
                  const SizedBox(width: 10),
                  LegendDot(color: AppColors.expense, label: 'Expense'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: chartMax,
                minY: 0,
                barGroups: weekly.asMap().entries.map((entry) {
                  final i = entry.key;
                  final expenseVal = entry.value;
                  final incomeVal = weeklyIncome[i];
                  final isToday = i == todayIndex;
                  final alpha = isToday ? 1.0 : 0.6;
                  return BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: incomeVal,
                        color: AppColors.income.withValues(alpha: alpha),
                        width: 10,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: chartMax,
                          color: isDark
                              ? AppColors.darkElevated
                              : AppColors.lightCard,
                        ),
                      ),
                      BarChartRodData(
                        toY: expenseVal,
                        color: AppColors.expense.withValues(alpha: alpha),
                        width: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= _days.length) {
                          return const SizedBox.shrink();
                        }
                        final isToday = i == todayIndex;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _days[i],
                            style: TextStyle(
                              color: isToday
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: gridColor,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppColors.darkElevated : Colors.white,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final isIncome = rodIndex == 0;
                      return BarTooltipItem(
                        '${isIncome ? 'Income' : 'Expense'}: ${CurrencyFormatter.format(rod.toY, symbol: currency)}',
                        TextStyle(
                          color: isIncome ? AppColors.income : AppColors.expense,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
              swapAnimationDuration: 600.ms,
              swapAnimationCurve: Curves.easeInOutCubic,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
        ],
      ),
    );
  }
}
