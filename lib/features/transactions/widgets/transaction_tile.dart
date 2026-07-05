import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/category_app_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/custom_category.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/settings_provider.dart';

class TransactionTile extends ConsumerWidget {
  final Transaction transaction;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final int index;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onDelete,
    required this.onEdit,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final customCats = ref.watch(customCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpense = transaction.type == TransactionType.expense;
    final amountColor = isExpense ? AppColors.expense : AppColors.income;
    final amountPrefix = isExpense ? '-' : '+';

    CustomCategory? customCat;
    if (transaction.customCategoryId != null) {
      for (final c in customCats) {
        if (c.id == transaction.customCategoryId) {
          customCat = c;
          break;
        }
      }
    }
    final color = customCat?.color ?? transaction.category.color;
    final icon = customCat?.icon ?? transaction.category.icon;
    final label = customCat?.label ?? transaction.category.label;

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(
          Icons.delete_rounded,
          color: AppColors.expense,
          size: 24,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Icon — show the chosen brand icon when one is set,
                  // otherwise fall back to the category icon.
                  _TileIcon(
                    appIcon: transaction.appIcon,
                    fallbackIcon: icon,
                    color: color,
                  ),
                  const SizedBox(width: 14),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        if (transaction.note?.isNotEmpty == true)
                          Text(
                            transaction.note!,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textLightSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '${DateFormatter.formatDate(transaction.date)} · ${DateFormatter.formatTime(transaction.date)}',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
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
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: amountColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isExpense ? 'Expense' : 'Income',
                          style: TextStyle(
                            color: amountColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
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
    ).animate(delay: (index * 50).ms).fadeIn().slideX(
          begin: 0.05,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Mirrors the visual treatment of the AppIconPicker tile so a transaction's
/// brand icon reads the same here as it does when the user picks it: 48×48
/// card-colored container with a subtle border, 4-px padding, and
/// `BoxFit.contain` on the asset.
class _AppIconBox extends StatelessWidget {
  final String appIcon;
  const _AppIconBox({required this.appIcon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          CategoryAppIcons.pathFor(appIcon),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final String? appIcon;
  final IconData fallbackIcon;
  final Color color;

  const _TileIcon({
    required this.appIcon,
    required this.fallbackIcon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (appIcon != null) return _AppIconBox(appIcon: appIcon!);
    return _fallbackBubble();
  }

  Widget _fallbackBubble() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(fallbackIcon, color: color, size: 22),
    );
  }
}
