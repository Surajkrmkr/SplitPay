import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/balance_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../shared/widgets/avatar_widget.dart';

class BalanceTile extends ConsumerWidget {
  final BalanceModel balance;
  final String groupId;
  final VoidCallback? onSettleUp;

  const BalanceTile({
    super.key,
    required this.balance,
    required this.groupId,
    this.onSettleUp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id ?? 'user_1';
    final currency = ref.watch(currencyProvider);
    final isCurrentUserInvolved =
        balance.fromUserId == currentUserId || balance.toUserId == currentUserId;
    final isYouOwing = balance.fromUserId == currentUserId;

    return GestureDetector(
      onTap: isYouOwing ? onSettleUp : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentUserInvolved
                ? (isYouOwing
                    ? AppColors.expense.withValues(alpha: 0.4)
                    : AppColors.income.withValues(alpha: 0.4))
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isCurrentUserInvolved ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // From avatar
            AvatarWidget(
              name: balance.fromUserName,
              imageUrl: balance.fromUserAvatar,
              size: 36,
            ),

            // Arrow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.expense,
              ),
            ),

            // To avatar
            AvatarWidget(
              name: balance.toUserName,
              imageUrl: balance.toUserAvatar,
              size: 36,
            ),

            const SizedBox(width: 12),

            // Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_displayName(balance.fromUserName, currentUserId, balance.fromUserId)} '
                    'owes '
                    '${_displayName(balance.toUserName, currentUserId, balance.toUserId)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textLightSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$currency${balance.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isYouOwing ? AppColors.expense : AppColors.income,
                    ),
                  ),
                ],
              ),
            ),

            // Settle up button for current user's debts
            if (isYouOwing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Settle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _displayName(String name, String currentUserId, String userId) {
    return userId == currentUserId ? 'You' : name;
  }
}
