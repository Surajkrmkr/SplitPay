import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';

class SpendingPieChart extends ConsumerStatefulWidget {
  const SpendingPieChart({super.key});

  @override
  ConsumerState<SpendingPieChart> createState() => _SpendingPieChartState();
}

class _SpendingPieChartState extends ConsumerState<SpendingPieChart> {
  int _touchedIndex = -1;
  TransactionType _selectedType = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final isExpense = _selectedType == TransactionType.expense;
    final breakdown = isExpense
        ? ref.watch(categoryBreakdownProvider)
        : ref.watch(categoryBreakdownIncomeProvider);
    final customCats = ref.watch(customCategoriesProvider);
    final typeColor = isExpense ? AppColors.expense : AppColors.income;
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = breakdown.values.fold(0.0, (a, b) => a + b);

    final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (breakdown.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'By Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _TypeToggle(
              selected: _selectedType,
              onChanged: (type) => setState(() {
                _selectedType = type;
                _touchedIndex = -1;
              }),
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 32,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              'No ${isExpense ? 'expenses' : 'income'} this month',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = sorted.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final display = resolveCategoryDisplay(e.key, customCats);
      final isTouched = i == _touchedIndex;
      final pct = total > 0 ? e.value / total * 100 : 0.0;

      return PieChartSectionData(
        value: e.value,
        color: display.color,
        radius: isTouched ? 68 : 58,
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        // Always show the category icon on the slice itself, rather than
        // only on touch — the legend pills below no longer have to carry
        // all the identification on their own.
        badgeWidget: Container(
          padding: EdgeInsets.all(isTouched ? 6 : 5),
          decoration: BoxDecoration(
            color: display.color,
            shape: BoxShape.circle,
            border: Border.all(color: bgColor, width: 1.5),
          ),
          child: Icon(display.icon,
              color: Colors.white, size: isTouched ? 14 : 12),
        ),
        badgePositionPercentageOffset: 1.05,
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'By Category',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                CurrencyFormatter.format(total, symbol: currency),
                style: TextStyle(
                  color: typeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TypeToggle(
            selected: _selectedType,
            onChanged: (type) => setState(() {
              _selectedType = type;
              _touchedIndex = -1;
            }),
            isDark: isDark,
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex =
                              response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                  swapAnimationDuration: 400.ms,
                  swapAnimationCurve: Curves.easeInOutCubic,
                ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(total, symbol: currency),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms).scale(
                begin: const Offset(0.8, 0.8),
                duration: 600.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 20),

          // Legend
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sorted.map((entry) {
              final pct = total > 0 ? entry.value / total * 100 : 0.0;
              final display = resolveCategoryDisplay(entry.key, customCats);
              return GestureDetector(
                onTap: () => _openCategoryTransactions(context, entry.key),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: display.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: display.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${display.label} ${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: display.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _openCategoryTransactions(BuildContext context, String categoryKey) {
    ref.read(categoryFilterProvider.notifier).state = {categoryKey};
    ref.read(transactionTypeFilterProvider.notifier).state =
        _selectedType == TransactionType.expense
            ? TransactionTypeFilter.expense
            : TransactionTypeFilter.income;
    context.push('/transactions');
  }
}

class _TypeToggle extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;
  final bool isDark;

  const _TypeToggle({
    required this.selected,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildOption(
                TransactionType.expense, 'Expense', AppColors.expense),
          ),
          Expanded(
            child: _buildOption(
                TransactionType.income, 'Income', AppColors.income),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(TransactionType type, String label, Color color) {
    final isSelected = selected == type;
    return GestureDetector(
      onTap: () => onChanged(type),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textTertiary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
