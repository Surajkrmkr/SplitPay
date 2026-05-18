import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/group_model.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';

class GroupCard extends ConsumerWidget {
  final GroupModel group;
  final int index;
  final VoidCallback? onTap;

  const GroupCard({
    super.key,
    required this.group,
    required this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final balancesAsync = ref.watch(groupBalancesProvider(group.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Group avatar
            AvatarWidget(
              imageUrl: group.avatar,
              name: group.name,
              size: 52,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textLightSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Updated ${_timeAgo(group.updatedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Balance chip
            balancesAsync.when(
              data: (summary) => _BalanceChip(
                owed: summary.totalOwed,
                lent: summary.totalLent,
                currency: currency,
              ),
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (index * 60).ms)
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.1, duration: 350.ms, curve: Curves.easeOut);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }
}

class _BalanceChip extends StatelessWidget {
  final double owed;
  final double lent;
  final String currency;

  const _BalanceChip({required this.owed, required this.lent, required this.currency});

  @override
  Widget build(BuildContext context) {
    final net = lent - owed;
    final isSettled = net.abs() < 0.01;
    final isPositive = net > 0;

    final color = isSettled
        ? AppColors.textTertiary
        : isPositive
            ? AppColors.income
            : AppColors.expense;

    final label = isSettled
        ? 'Settled'
        : isPositive
            ? '+$currency${net.toStringAsFixed(0)}'
            : '-$currency${net.abs().toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
