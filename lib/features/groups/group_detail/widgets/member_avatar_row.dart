import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/member_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/widgets/avatar_widget.dart';

class MemberAvatarRow extends ConsumerWidget {
  final List<MemberModel> members;
  final int maxVisible;
  final double avatarSize;

  const MemberAvatarRow({
    super.key,
    required this.members,
    this.maxVisible = 5,
    this.avatarSize = 36,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final visible = members.take(maxVisible).toList();
    final overflow = members.length - maxVisible;
    final overlapOffset = avatarSize * 0.65;

    return GestureDetector(
      onTap: () => _showMemberList(context, currentUserId),
      child: SizedBox(
        height: avatarSize + 4, // +4 for 2px border top+bottom
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Overlapping avatars
            SizedBox(
              width: visible.length * overlapOffset +
                  avatarSize * (1 - 0.65) +
                  (overflow > 0 ? overlapOffset + avatarSize + 4 : 0) +
                  4, // +4 for right border
              child: Stack(
                children: [
                  ...visible.asMap().entries.map((e) {
                    return Positioned(
                      left: e.key * overlapOffset,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkBg : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: AvatarWidget(
                          name: e.value.name,
                          imageUrl: e.value.avatar,
                          size: avatarSize,
                        ),
                      ),
                    );
                  }),
                  if (overflow > 0)
                    Positioned(
                      left: visible.length * overlapOffset,
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkBg : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+$overflow',
                            style: TextStyle(
                              fontSize: avatarSize * 0.28,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textLightSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberList(BuildContext context, String? currentUserId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Members (${members.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 12),
            ...members.map((m) {
              final isYou = m.userId == currentUserId;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AvatarWidget(
                  name: m.name,
                  imageUrl: m.avatar,
                  size: 40,
                ),
                title: Text(
                  isYou ? '${m.name} (You)' : m.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textLight,
                  ),
                ),
                subtitle: Text(
                  m.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: (isYou || m.isAdmin)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isYou) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (m.isAdmin) const SizedBox(width: 6),
                          ],
                          if (m.isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}
