import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../features/add_transaction/add_transaction_sheet.dart';
import '../../features/groups/add_expense/add_expense_sheet.dart';
import '../../data/models/group_model.dart';
import '../../providers/group_provider.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/utils/guest_guard.dart';

class ShortcutLaunchScreen extends ConsumerStatefulWidget {
  final bool addGroupExpense;

  const ShortcutLaunchScreen.addExpense({super.key}) : addGroupExpense = false;

  const ShortcutLaunchScreen.addGroupExpense({super.key})
      : addGroupExpense = true;

  @override
  ConsumerState<ShortcutLaunchScreen> createState() =>
      _ShortcutLaunchScreenState();
}

class _ShortcutLaunchScreenState extends ConsumerState<ShortcutLaunchScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.addGroupExpense) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) requireAuth(context, ref, _openPersonalExpense);
      });
    }
  }

  Future<void> _openPersonalExpense() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    );
    if (mounted) context.go('/home');
  }

  Future<void> _openGroupExpense(GroupModel group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(group: group),
    );
    if (mounted) context.go('/groups');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.addGroupExpense) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final groups = ref.watch(groupsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardTheme.color ??
        (isDark ? AppColors.darkCard : AppColors.lightSurface);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/groups'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add group expense',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose a group',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: groups.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load groups',
                  subtitle: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => ref.read(groupsProvider.notifier).refresh(),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.group_add_rounded,
                      title: 'No groups yet',
                      subtitle: 'Create or join a group to split an expense.',
                      actionLabel: 'Go to groups',
                      onAction: () => context.go('/groups'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _GroupOption(
                      group: items[index],
                      cardColor: cardColor,
                      isDark: isDark,
                      onTap: () => _openGroupExpense(items[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupOption extends StatelessWidget {
  final GroupModel group;
  final Color cardColor;
  final bool isDark;
  final VoidCallback onTap;

  const _GroupOption({
    required this.group,
    required this.cardColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              AvatarWidget(
                imageUrl: group.avatar,
                name: group.name,
                size: 48,
                backgroundColor: primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.memberCount} ${group.memberCount == 1 ? 'member' : 'members'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
