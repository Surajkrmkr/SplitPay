import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/legend_dot.dart';

class MonthlyTrendChart extends ConsumerWidget {
  const MonthlyTrendChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(monthlyTrendProvider);
    final incomes = ref.watch(monthlyIncomeTrendProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allValues = [...expenses, ...incomes];
    final maxVal = allValues.reduce((a, b) => a > b ? a : b);
    final chartMax = maxVal == 0 ? 100.0 : maxVal * 1.25;

    final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final expenseSpots = expenses
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final incomeSpots = incomes
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final now = DateTime.now();
    final monthLabels = List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i), 1);
      return DateFormat('MMM').format(m);
    });

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
                '6-Month Trend',
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
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: chartMax,
                lineBarsData: [
                  // Income line
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: AppColors.income,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, index) =>
                          FlDotCirclePainter(
                        radius: index == 5 ? 5 : 3,
                        color: index == 5
                            ? AppColors.income
                            : AppColors.income.withValues(alpha: 0.5),
                        strokeWidth: index == 5 ? 2 : 0,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.income.withValues(alpha: 0.12),
                          AppColors.income.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Expense line
                  LineChartBarData(
                    spots: expenseSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: AppColors.expense,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, index) =>
                          FlDotCirclePainter(
                        radius: index == 5 ? 5 : 3,
                        color: index == 5
                            ? AppColors.expense
                            : AppColors.expense.withValues(alpha: 0.5),
                        strokeWidth: index == 5 ? 2 : 0,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.expense.withValues(alpha: 0.12),
                          AppColors.expense.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= monthLabels.length || i != value) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            monthLabels[i],
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10,
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
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppColors.darkElevated : Colors.white,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                      final isIncome = s.barIndex == 0;
                      return LineTooltipItem(
                        '${isIncome ? 'Income' : 'Expense'}: ${CurrencyFormatter.format(s.y, symbol: currency)}',
                        TextStyle(
                          color:
                              isIncome ? AppColors.income : AppColors.expense,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              duration: 600.ms,
              curve: Curves.easeInOutCubic,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
        ],
      ),
    );
  }
}
