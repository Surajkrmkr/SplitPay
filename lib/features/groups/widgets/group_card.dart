import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/models/member_model.dart';
import '../../../data/models/group_model.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/skeleton_loader.dart';

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
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    final currency = ref.watch(currencyProvider);
    final balancesAsync = ref.watch(groupBalancesProvider(group.id));
    final activityAsync = ref.watch(groupActivityProvider(group.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? cardBg : Colors.white,
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
              backgroundColor: primary.withValues(alpha: 0.8),
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
                  _MemberAvatarStack(
                    members: group.members,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  activityAsync.when(
                    data: (activities) {
                      if (activities.isEmpty) {
                        return const _ActivityLabel(text: 'No activity yet');
                      }
                      final latest = activities.reduce(
                        (current, activity) =>
                            activity.createdAt.isAfter(current.createdAt)
                                ? activity
                                : current,
                      );
                      return _ActivityLabel(
                        text:
                            '${_activityLabel(latest.type)} · ${_timeAgo(latest.createdAt)}',
                      );
                    },
                    loading: () =>
                        const _ActivityLabel(text: 'Loading activity…'),
                    error: (_, __) =>
                        const _ActivityLabel(text: 'Activity unavailable'),
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
              loading: () =>
                  const SkeletonBox(width: 64, height: 26, borderRadius: 20),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 60).ms).fadeIn(duration: 350.ms);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }

  String _activityLabel(ActivityType type) {
    return switch (type) {
      ActivityType.expenseAdded => 'Expense added',
      ActivityType.expenseUpdated => 'Expense updated',
      ActivityType.expenseDeleted => 'Expense removed',
      ActivityType.settlementCompleted => 'Settled',
      ActivityType.memberJoined => 'Member joined',
      ActivityType.memberRemoved => 'Member left',
      ActivityType.groupCreated => 'Group created',
    };
  }
}

class _ActivityLabel extends StatelessWidget {
  const _ActivityLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _MemberAvatarStack extends StatelessWidget {
  const _MemberAvatarStack({
    required this.members,
    required this.isDark,
  });

  final List<MemberModel> members;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 22.0;
    const overlap = 7.0;
    final visibleMembers = members.take(3).toList();
    final stackWidth = visibleMembers.isEmpty
        ? 0.0
        : avatarSize + (visibleMembers.length - 1) * (avatarSize - overlap);

    return Row(
      children: [
        if (visibleMembers.isNotEmpty)
          SizedBox(
            width: stackWidth,
            height: avatarSize,
            child: Stack(
              children: [
                for (var index = 0; index < visibleMembers.length; index++)
                  Positioned(
                    left: index * (avatarSize - overlap),
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: AvatarWidget(
                        imageUrl: visibleMembers[index].avatar,
                        name: visibleMembers[index].name,
                        size: avatarSize - 3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (visibleMembers.isNotEmpty) const SizedBox(width: 7),
        Text(
          '${members.length} ${members.length == 1 ? 'member' : 'members'}',
          style: TextStyle(
            fontSize: 11,
            color:
                isDark ? AppColors.textSecondary : AppColors.textLightSecondary,
          ),
        ),
      ],
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final double owed;
  final double lent;
  final String currency;

  const _BalanceChip(
      {required this.owed, required this.lent, required this.currency});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final net = lent - owed;
    final isSettled = net.abs() < 0.01;
    final isPositive = net > 0;

    final color = isSettled
        ? AppColors.textTertiary
        : isPositive
            ? primary
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
