import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';

class MyBalanceSummary extends ConsumerWidget {
  const MyBalanceSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final groups = ref.watch(groupsProvider).valueOrNull ?? [];

    // Aggregate balances across all groups. While any group's balance is
    // still loading, hold off rendering totals to avoid a premature ₹0 flash.
    double totalOwed = 0;
    double totalLent = 0;
    bool anyLoading = false;

    for (final group in groups) {
      final balancesAsync = ref.watch(groupBalancesProvider(group.id));
      if (balancesAsync.isLoading) {
        anyLoading = true;
        continue;
      }
      final balances = balancesAsync.valueOrNull;
      if (balances != null) {
        totalOwed += balances.totalOwed;
        totalLent += balances.totalLent;
      }
    }

    if (anyLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    final net = totalLent - totalOwed;
    final isPositive = net >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: "You're owed",
              value: '$currency${totalLent.toStringAsFixed(0)}',
              color: AppColors.income,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          Expanded(
            child: _StatItem(
              label: 'You owe',
              value: '$currency${totalOwed.toStringAsFixed(0)}',
              color: AppColors.expense,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          Expanded(
            child: _StatItem(
              label: 'Net balance',
              value:
                  '${isPositive ? '+' : ''}$currency${net.abs().toStringAsFixed(0)}',
              color: isPositive ? AppColors.income : AppColors.expense,
              showArrow: true,
              isPositive: isPositive,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool showArrow;
  final bool isPositive;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    this.showArrow = false,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showArrow) ...[
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
