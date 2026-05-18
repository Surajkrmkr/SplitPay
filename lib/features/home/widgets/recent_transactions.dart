import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/custom_category.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/empty_state.dart';

class RecentTransactions extends ConsumerWidget {
  const RecentTransactions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(recentTransactionsProvider);
    final currency = ref.watch(currencyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              GestureDetector(
                onTap: () => context.push('/transactions'),
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              subtitle: 'Tap the + button to add your first transaction',
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: transactions.asMap().entries.map((entry) {
                final i = entry.key;
                final tx = entry.value;
                return _TransactionItem(
                  transaction: tx,
                  currency: currency,
                ).animate(delay: (i * 60).ms).fadeIn().slideX(
                      begin: 0.1,
                      end: 0,
                      curve: Curves.easeOutCubic,
                    );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _TransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final String currency;

  const _TransactionItem({
    required this.transaction,
    required this.currency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customCats = ref.watch(customCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpense = transaction.type == TransactionType.expense;
    final amountColor = isExpense ? AppColors.expense : AppColors.income;
    final amountPrefix = isExpense ? '-' : '+';

    CustomCategory? customCat;
    if (transaction.customCategoryId != null) {
      for (final c in customCats) {
        if (c.id == transaction.customCategoryId) { customCat = c; break; }
      }
    }
    final color = customCat?.color ?? transaction.category.color;
    final icon = customCat?.icon ?? transaction.category.icon;
    final label = customCat?.label ?? transaction.category.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.note?.isNotEmpty == true
                      ? transaction.note!
                      : DateFormatter.formatDate(transaction.date),
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textLightSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix${CurrencyFormatter.format(transaction.amount, symbol: currency)}',
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormatter.formatShort(transaction.date),
                style: TextStyle(
                  color: isDark
                      ? AppColors.textTertiary
                      : AppColors.textLightSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
