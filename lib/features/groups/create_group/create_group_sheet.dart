import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/group_icons.dart';
import '../../../data/models/member_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../shared/widgets/sp_button.dart';

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _memberSearchController = TextEditingController();
  final _memberListScrollController = ScrollController();
  final Set<String> _selectedMemberIds = {};

  String _selectedIconKey = GroupIcons.defaultKey;
  String _memberSearchQuery = '';
  bool _showSuggestedUsers = false;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _memberSearchController.dispose();
    _memberListScrollController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      final group = await ref.read(groupsProvider.notifier).createGroup(
            name,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            avatar: GroupIcons.encode(_selectedIconKey),
            memberIds: _selectedMemberIds.toList(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        context.push('/groups/${group.id}/invite');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isValid = _nameController.text.trim().isNotEmpty;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final safeAreaBottom = MediaQuery.of(context).viewPadding.bottom;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final previousGroups = ref.watch(groupsProvider).valueOrNull ?? [];
    final suggestionsById = <String, MemberModel>{};
    for (final group in previousGroups) {
      for (final member in group.members) {
        if (member.userId != currentUserId) {
          suggestionsById.putIfAbsent(member.userId, () => member);
        }
      }
    }
    final suggestedUsers = suggestionsById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final filteredUsers = suggestedUsers.where((member) {
      final query = _memberSearchQuery.trim().toLowerCase();
      return query.isEmpty ||
          member.name.toLowerCase().contains(query) ||
          member.email.toLowerCase().contains(query);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'New Group',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textLight,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Live preview avatar
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: (GroupIcons.colors[_selectedIconKey] ??
                                  Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: GroupIcons.colors[_selectedIconKey] ??
                                Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          GroupIcons.all[_selectedIconKey],
                          color: GroupIcons.colors[_selectedIconKey] ??
                              Theme.of(context).colorScheme.primary,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _SectionLabel(label: 'Group Icon', isDark: isDark),
                    const SizedBox(height: 10),
                    _IconPicker(
                      selectedKey: _selectedIconKey,
                      isDark: isDark,
                      onSelect: (key) => setState(() => _selectedIconKey = key),
                    ),
                    const SizedBox(height: 22),

                    _SectionLabel(label: 'Group Name *', isDark: isDark),
                    const SizedBox(height: 8),
                    _StyledTextField(
                      controller: _nameController,
                      hint: 'e.g. Goa Trip 2024',
                      isDark: isDark,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    _SectionLabel(
                        label: 'Description (optional)', isDark: isDark),
                    const SizedBox(height: 8),
                    _StyledTextField(
                      controller: _descController,
                      hint: 'What is this group for?',
                      isDark: isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    _SectionLabel(
                      label: 'Suggested members (optional)',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(
                          () => _showSuggestedUsers = !_showSuggestedUsers,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.group_add_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedMemberIds.isEmpty
                                      ? 'Select from previous group members'
                                      : '${_selectedMemberIds.length} selected',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textLight,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                _showSuggestedUsers
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_showSuggestedUsers) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _memberSearchController,
                        onChanged: (query) =>
                            setState(() => _memberSearchQuery = query),
                        decoration: InputDecoration(
                          hintText: 'Search name or email',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          filled: true,
                          fillColor:
                              isDark ? AppColors.darkCard : AppColors.lightCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (filteredUsers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            suggestedUsers.isEmpty
                                ? 'Members from your groups will appear here.'
                                : 'No matching users.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 220,
                          child: Scrollbar(
                            controller: _memberListScrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _memberListScrollController,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final member = filteredUsers[index];
                                final selected =
                                    _selectedMemberIds.contains(member.userId);
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  value: selected,
                                  title: Text(
                                    member.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    member.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  secondary: CircleAvatar(
                                    radius: 17,
                                    backgroundImage: member.avatar != null
                                        ? NetworkImage(member.avatar!)
                                        : null,
                                    child: member.avatar == null
                                        ? Text(member.initials)
                                        : null,
                                  ),
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked ?? false) {
                                        _selectedMemberIds.add(member.userId);
                                      } else {
                                        _selectedMemberIds
                                            .remove(member.userId);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),

                    // Invite hint
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              color: AppColors.secondary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invite by share code',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Once the group is created, you\'ll get a share code & QR to invite members.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 250.ms),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  (keyboardHeight > 0 ? keyboardHeight : safeAreaBottom) + 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.darkBorder),
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SpButton(
                        label: 'Create Group',
                        onTap: isValid && !_creating ? _createGroup : null,
                        isLoading: _creating,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String selectedKey;
  final bool isDark;
  final ValueChanged<String> onSelect;

  const _IconPicker({
    required this.selectedKey,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final entries = GroupIcons.all.entries.toList();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final e = entries[i];
          final selected = e.key == selectedKey;
          final color =
              GroupIcons.colors[e.key] ?? Theme.of(context).colorScheme.primary;
          final cardBg =
              Theme.of(context).cardTheme.color ?? AppColors.darkCard;
          return GestureDetector(
            onTap: () => onSelect(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.18)
                    : (isDark ? cardBg : AppColors.lightCard),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? color
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Icon(
                e.value,
                color: selected ? color : AppColors.textSecondary,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textSecondary : AppColors.textLightSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      inputFormatters: [LengthLimitingTextInputFormatter(50)],
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(
        color: isDark ? Colors.white : AppColors.textLight,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
