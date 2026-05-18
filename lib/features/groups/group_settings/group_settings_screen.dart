import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/group_model.dart';
import '../../../data/models/member_model.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
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
        title: const Text('Group Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (group) {
          final isAdmin = group.members
              .any((m) => m.userId == currentUserId && m.isAdmin);
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
                _DeleteGroupTile(groupId: widget.groupId, isDark: isDark, ref: ref),
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
  const _RenameGroupTile({required this.group, required this.isDark, required this.ref});

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
        child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
      ),
      title: Text('Rename Group', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.textLight)),
      subtitle: Text(group.name, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: () => _showRenameDialog(context),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: const Text('Rename Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Group name', border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              ctx.pop();
              try {
                await ref.read(groupApiServiceProvider).updateGroup(
                  group.id,
                  name: name,
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                );
                ref.invalidate(groupDetailProvider(group.id));
                ref.invalidate(groupsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Group updated'), backgroundColor: AppColors.income, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
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
      leading: AvatarWidget(name: member.name, imageUrl: member.avatar, size: 40),
      title: Text(
        '${member.name}${isMe ? ' (You)' : ''}',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.textLight),
      ),
      subtitle: Text(member.email, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: member.isAdmin ? AppColors.primary.withValues(alpha: 0.12) : AppColors.textSecondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              member.isAdmin ? 'Admin' : 'Member',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: member.isAdmin ? AppColors.primary : AppColors.textSecondary),
            ),
          ),
          if (isCurrentUserAdmin && !isMe) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
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
                    Icon(Icons.person_remove_alt_1_rounded, size: 18, color: Colors.red),
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
        await ref.read(groupApiServiceProvider).updateMemberRole(groupId, member.userId, newRole);
        ref.invalidate(groupDetailProvider(groupId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${member.name} is now ${newRole == 'ADMIN' ? 'an Admin' : 'a Member'}'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense));
        }
      }
    } else if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Member'),
          content: Text('Remove ${member.name} from the group?'),
          actions: [
            TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.expense), onPressed: () => ctx.pop(true), child: const Text('Remove')),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          await ref.read(groupApiServiceProvider).removeMember(groupId, member.userId);
          ref.invalidate(groupDetailProvider(groupId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${member.name} removed'),
              backgroundColor: AppColors.income,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense));
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
  const _DeleteGroupTile({required this.groupId, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.expense, size: 20),
      ),
      title: const Text('Delete Group', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.expense)),
      subtitle: const Text('This action cannot be undone', style: TextStyle(fontSize: 12)),
      onTap: () => _confirmDelete(context),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('This will permanently delete the group, all expenses, and all balances. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => ctx.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(groupApiServiceProvider).deleteGroup(groupId);
        ref.invalidate(groupsProvider);
        if (context.mounted) context.go('/groups');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense));
        }
      }
    }
  }
}
