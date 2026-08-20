import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/budget_provider.dart';

class BudgetFilterChips extends ConsumerWidget {
  const BudgetFilterChips({super.key});

  static const _entries = [
    ('All', BudgetPeriodFilter.all),
    ('Daily', BudgetPeriodFilter.daily),
    ('Weekly', BudgetPeriodFilter.weekly),
    ('Monthly', BudgetPeriodFilter.monthly),
    ('Yearly', BudgetPeriodFilter.yearly),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(budgetPeriodFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = _entries[i].$1;
          final value = _entries[i].$2;
          final isSelected = selected == value;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(budgetPeriodFilterProvider.notifier).state = value;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary
                    : isDark
                        ? cardBg
                        : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? primary
                      : isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : isDark
                          ? AppColors.textSecondary
                          : AppColors.textLightSecondary,
                ),
              ),
            ),
          );
        },
      ),
    ).animate(delay: 100.ms).fadeIn(duration: 300.ms);
  }
}
