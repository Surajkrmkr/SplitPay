import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/auth_user_model.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/group_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/sp_button.dart';

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();

  final List<AuthUserModel> _addedMembers = [];
  List<AuthUserModel> _searchResults = [];
  bool _searching = false;
  bool _creating = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _searchQuery = q;
      _searching = q.isNotEmpty;
    });
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results =
          await ref.read(groupApiServiceProvider).searchUsers(q);
      if (mounted && _searchQuery == q) {
        setState(() {
          _searchResults = results
              .where((u) => !_addedMembers.any((m) => m.id == u.id))
              .toList();
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
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
            memberIds: _addedMembers.map((m) => m.id).toList(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        context.push('/groups/${group.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            backgroundColor: AppColors.expense,
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

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
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

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    // Group name field
                    _SectionLabel(label: 'Group Name *', isDark: isDark),
                    const SizedBox(height: 8),
                    _StyledTextField(
                      controller: _nameController,
                      hint: 'e.g. Goa Trip 2024',
                      isDark: isDark,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Description field
                    _SectionLabel(label: 'Description (optional)', isDark: isDark),
                    const SizedBox(height: 8),
                    _StyledTextField(
                      controller: _descController,
                      hint: 'What is this group for?',
                      isDark: isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Add members
                    _SectionLabel(label: 'Add Members', isDark: isDark),
                    const SizedBox(height: 8),
                    _StyledTextField(
                      controller: _searchController,
                      hint: 'Search by name or email…',
                      isDark: isDark,
                      prefixIcon: Icons.search_rounded,
                      onChanged: _search,
                    ),
                    const SizedBox(height: 12),

                    // Added members chips
                    if (_addedMembers.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _addedMembers
                            .map((u) => _MemberChip(
                                  user: u,
                                  onRemove: () =>
                                      setState(() => _addedMembers.remove(u)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Search results
                    if (_searching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else if (_searchResults.isNotEmpty)
                      ..._searchResults.map(
                        (u) => _UserResultTile(
                          user: u,
                          onAdd: () {
                            setState(() {
                              _addedMembers.add(u);
                              _searchResults.remove(u);
                              _searchController.clear();
                              _searchResults = [];
                            });
                          },
                          isDark: isDark,
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // Bottom action bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  20, 12, 20,
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
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.maxLines = 1,
    this.prefixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(
        color: isDark ? Colors.white : AppColors.textLight,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.textTertiary, size: 20)
            : null,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final AuthUserModel user;
  final VoidCallback onRemove;

  const _MemberChip({required this.user, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: AvatarWidget(name: user.name, size: 24),
      label: Text(user.name.split(' ').first),
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      onDeleted: onRemove,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      labelStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      deleteIconColor: AppColors.primary,
      side: BorderSide.none,
    );
  }
}

class _UserResultTile extends StatelessWidget {
  final AuthUserModel user;
  final VoidCallback onAdd;
  final bool isDark;

  const _UserResultTile({
    required this.user,
    required this.onAdd,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AvatarWidget(
        imageUrl: user.avatar,
        name: user.name,
        size: 40,
      ),
      title: Text(
        user.name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textLight,
        ),
      ),
      subtitle: Text(
        user.email,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: GestureDetector(
        onTap: onAdd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '+ Add',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
