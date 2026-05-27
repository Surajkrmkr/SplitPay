import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';

class CategoryOverview extends ConsumerWidget {
  const CategoryOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown = ref.watch(categoryBreakdownProvider);
    final currency = ref.watch(currencyProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();

    final now = DateTime.now();
    final isCurrent = selectedMonth.year == now.year &&
        selectedMonth.month == now.month;
    final monthLabel = isCurrent
        ? 'This month'
        : DateFormat('MMM yyyy').format(selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Categories',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                monthLabel,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
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
        ),
      ],
    );
  }
}

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
    final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
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
