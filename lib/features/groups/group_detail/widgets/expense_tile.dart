import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/group_expense_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/settings_provider.dart';

class ExpenseTile extends ConsumerWidget {
  final GroupExpenseModel expense;
  final bool showDivider; // kept for API compat but unused in new design
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.showDivider = true,
    this.onEdit,
    this.onDelete,
  });

  static IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('food') || t.contains('lunch') || t.contains('dinner') ||
        t.contains('breakfast') || t.contains('restaurant') ||
        t.contains('shack') || t.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (t.contains('hotel') || t.contains('stay') || t.contains('resort') ||
        t.contains('airbnb')) {
      return Icons.hotel_rounded;
    }
    if (t.contains('travel') || t.contains('taxi') || t.contains('uber') ||
        t.contains('cab') || t.contains('fuel') || t.contains('petrol') ||
        t.contains('flight')) {
      return Icons.directions_car_rounded;
    }
    if (t.contains('drink') || t.contains('beer') || t.contains('wine') ||
        t.contains('alcohol')) {
      return Icons.local_bar_rounded;
    }
    if (t.contains('coffee') || t.contains('tea')) { return Icons.local_cafe_rounded; }
    if (t.contains('groceri') || t.contains('supermarket') || t.contains('market')) {
      return Icons.shopping_cart_rounded;
    }
    if (t.contains('bill') || t.contains('electric') || t.contains('rent') ||
        t.contains('utility')) {
      return Icons.receipt_long_rounded;
    }
    if (t.contains('movie') || t.contains('cinema') || t.contains('entertain')) {
      return Icons.movie_rounded;
    }
    if (t.contains('dive') || t.contains('scuba') || t.contains('swim')) {
      return Icons.scuba_diving_rounded;
    }
    return Icons.attach_money_rounded;
  }

  static Color _colorFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('food') || t.contains('lunch') || t.contains('dinner') ||
        t.contains('restaurant') || t.contains('shack')) {
      return AppColors.catFood;
    }
    if (t.contains('hotel') || t.contains('stay') || t.contains('resort') ||
        t.contains('travel') || t.contains('taxi') || t.contains('fuel') ||
        t.contains('cab') || t.contains('flight')) {
      return AppColors.catTravel;
    }
    if (t.contains('drink') || t.contains('coffee') || t.contains('tea')) {
      return AppColors.catEntertainment;
    }
    if (t.contains('groceri') || t.contains('market')) { return AppColors.catShopping; }
    if (t.contains('bill') || t.contains('rent') || t.contains('electric')) {
      return AppColors.catBills;
    }
    if (t.contains('movie') || t.contains('entertain')) { return AppColors.catEntertainment; }
    return AppColors.secondary;
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    final currency = ref.watch(currencyProvider);
    final isPaidByMe = expense.paidById == currentUserId;
    final myShare = expense.shareForUser(currentUserId);
    final accentColor = _colorFor(expense.title);

    final String statusLabel;
    final Color statusColor;
    if (isPaidByMe) {
      statusLabel = 'you paid';
      statusColor = AppColors.income;
    } else if (myShare > 0) {
      statusLabel = 'owe $currency${myShare.toStringAsFixed(0)}';
      statusColor = AppColors.expense;
    } else {
      statusLabel = 'not involved';
      statusColor = AppColors.textTertiary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left accent strip
                Container(width: 4, color: accentColor),

                // Icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_iconFor(expense.title), color: accentColor, size: 20),
                  ),
                ),

                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          expense.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textLight,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${isPaidByMe ? 'You' : expense.paidByName} · ${_formatDate(expense.date)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Amount + status
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$currency${expense.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textLight,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions menu
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 18),
                    color: isDark ? AppColors.darkCard : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'edit') onEdit?.call();
                      if (val == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ]),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                    ],
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
