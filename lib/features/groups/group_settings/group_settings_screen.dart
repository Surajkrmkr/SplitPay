import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../data/models/group_model.dart';
import '../../../data/models/member_model.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/skeleton_loader.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        leadingWidth: 56,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Center(child: AppBackButton()),
        ),
        title: const Text('Group Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: groupAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            const SkeletonBox(width: 140, height: 16, borderRadius: 6),
            const SizedBox(height: 12),
            const SkeletonBox(
                width: double.infinity, height: 56, borderRadius: 12),
            const SizedBox(height: 24),
            const SkeletonBox(width: 100, height: 14, borderRadius: 6),
            const SizedBox(height: 10),
            ...List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SkeletonBox(
                    width: double.infinity, height: 56, borderRadius: 12),
              ),
            ),
          ],
        ),
        error: (e, _) => Center(child: Text(friendlyErrorMessage(e))),
        data: (group) {
          final isAdmin =
              group.members.any((m) => m.userId == currentUserId && m.isAdmin);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (isAdmin) ...[
                _SectionHeader('Group Info', isDark),
                _RenameGroupTile(group: group, isDark: isDark, ref: ref),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              _SectionHeader('Members (${group.members.length})', isDark),
              ...group.members.map((m) => _MemberTile(
                    member: m,
                    currentUserId: currentUserId,
                    isCurrentUserAdmin: isAdmin,
                    groupId: widget.groupId,
                    isDark: isDark,
                    ref: ref,
                  )),
              if (isAdmin) ...[
                _SectionHeader('Danger Zone', isDark),
                _DeleteGroupTile(
                    groupId: widget.groupId, isDark: isDark, ref: ref),
              ],
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader(this.title, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Rename group ─────────────────────────────────────────────

class _RenameGroupTile extends StatelessWidget {
  final GroupModel group;
  final bool isDark;
  final WidgetRef ref;
  const _RenameGroupTile(
      {required this.group, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child:
            const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
      ),
      title: Text('Rename Group',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textLight)),
      subtitle: Text(group.name,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textSecondary),
      onTap: () => _showRenameDialog(context),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Edit Group Info',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Update your group name and description',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Group Name',
                        prefixIcon: const Icon(Icons.group_rounded, size: 20),
                        filled: true,
                        fillColor:
                            isDark ? AppColors.darkCard : AppColors.lightBg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Icon(Icons.notes_rounded, size: 20),
                        ),
                        filled: true,
                        fillColor:
                            isDark ? AppColors.darkCard : AppColors.lightBg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => ctx.pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textLightSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;
                                ctx.pop();
                                try {
                                  await ref
                                      .read(groupApiServiceProvider)
                                      .updateGroup(
                                        group.id,
                                        name: name,
                                        description:
                                            descController.text.trim().isEmpty
                                                ? null
                                                : descController.text.trim(),
                                      );
                                  ref.invalidate(groupDetailProvider(group.id));
                                  ref.invalidate(groupsProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: const Text('Group updated'),
                                          backgroundColor: AppColors.income,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12))),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(friendlyErrorMessage(e)),
                                      backgroundColor: AppColors.expense,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ));
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Save Changes',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Member tile ──────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final MemberModel member;
  final String currentUserId;
  final bool isCurrentUserAdmin;
  final String groupId;
  final bool isDark;
  final WidgetRef ref;

  const _MemberTile({
    required this.member,
    required this.currentUserId,
    required this.isCurrentUserAdmin,
    required this.groupId,
    required this.isDark,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = member.userId == currentUserId;
    return ListTile(
      leading:
          AvatarWidget(name: member.name, imageUrl: member.avatar, size: 40),
      title: Text(
        '${member.name}${isMe ? ' (You)' : ''}',
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : AppColors.textLight),
      ),
      subtitle: Text(member.email,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: member.isAdmin
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.textSecondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              member.isAdmin ? 'Admin' : 'Member',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: member.isAdmin
                      ? AppColors.primary
                      : AppColors.textSecondary),
            ),
          ),
          if (isCurrentUserAdmin && !isMe) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary, size: 20),
              color: isDark ? AppColors.darkCard : Colors.white,
              onSelected: (val) => _handleAction(context, val),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'role',
                  child: Row(children: [
                    const Icon(Icons.swap_horiz_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(member.isAdmin ? 'Make Member' : 'Make Admin'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(children: [
                    Icon(Icons.person_remove_alt_1_rounded,
                        size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Remove', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    if (action == 'role') {
      final newRole = member.isAdmin ? 'MEMBER' : 'ADMIN';
      try {
        await ref
            .read(groupApiServiceProvider)
            .updateMemberRole(groupId, member.userId, newRole);
        ref.invalidate(groupDetailProvider(groupId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${member.name} is now ${newRole == 'ADMIN' ? 'an Admin' : 'a Member'}'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } else if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B6B),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.person_remove_alt_1_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 12),
                      const Text('Remove Member',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    AppColors.expense.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.expense, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : AppColors.textLight),
                                  children: [
                                    TextSpan(
                                        text: member.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const TextSpan(
                                        text:
                                            ' will be removed from this group.'),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => ctx.pop(false),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                side: BorderSide(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                              ),
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : AppColors.textLightSecondary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => ctx.pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.expense,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Remove',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (confirmed == true) {
        try {
          await ref
              .read(groupApiServiceProvider)
              .removeMember(groupId, member.userId);
          ref.invalidate(groupDetailProvider(groupId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${member.name} removed'),
              backgroundColor: AppColors.income,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(friendlyErrorMessage(e)),
              backgroundColor: AppColors.expense,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          }
        }
      }
    }
  }
}

// ── Delete group ─────────────────────────────────────────────

class _DeleteGroupTile extends StatelessWidget {
  final String groupId;
  final bool isDark;
  final WidgetRef ref;
  const _DeleteGroupTile(
      {required this.groupId, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: AppColors.expense.withValues(alpha: 0.12),
            shape: BoxShape.circle),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.expense, size: 20),
      ),
      title: const Text('Delete Group',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.expense)),
      subtitle: const Text('This action cannot be undone',
          style: TextStyle(fontSize: 12)),
      onTap: () => _confirmDelete(context),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.delete_forever_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 12),
                    const Text('Delete Group',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('This action is irreversible',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.expense.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.expense, size: 18),
                              const SizedBox(width: 8),
                              Text('This will permanently delete:',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.expense)),
                            ]),
                            const SizedBox(height: 10),
                            ...[
                              'All group expenses',
                              'All balances and settlements',
                              'All group members and history'
                            ].map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(children: [
                                  const SizedBox(width: 4),
                                  Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                          color: AppColors.expense,
                                          shape: BoxShape.circle)),
                                  const SizedBox(width: 10),
                                  Text(item,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white70
                                              : AppColors.textLight)),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => ctx.pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            ),
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: isDark
                                        ? AppColors.textSecondary
                                        : AppColors.textLightSecondary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => ctx.pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.expense,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Delete Group',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(groupApiServiceProvider).deleteGroup(groupId);
        ref.invalidate(groupsProvider);
        if (context.mounted) context.go('/groups');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    }
  }
}
