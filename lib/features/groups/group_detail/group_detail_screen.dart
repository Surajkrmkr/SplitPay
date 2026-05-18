import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/models/group_model.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../add_expense/add_expense_sheet.dart';
import '../add_expense/edit_expense_sheet.dart';
import '../settle_up/settle_up_sheet.dart';
import 'widgets/balance_tile.dart';
import 'widgets/expense_tile.dart';
import 'widgets/member_avatar_row.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupAsync = ref.watch(groupDetailProvider(groupId));

    return groupAsync.when(
      loading: () => Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Group'),
        ),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load group',
          subtitle: e.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
      ),
      data: (group) => DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useRootNavigator: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddExpenseSheet(group: group),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add Expense',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                title: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.group_add_rounded),
                    tooltip: 'Invite',
                    onPressed: () => context.push('/groups/$groupId/invite'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: 'Settings',
                    onPressed: () => context.push('/groups/$groupId/settings'),
                  ),
                ],
                bottom: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor:
                      isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  tabs: const [
                    Tab(text: 'Balances'),
                    Tab(text: 'Expenses'),
                    Tab(text: 'Activity'),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (group.description != null) ...[
                        Text(
                          group.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      MemberAvatarRow(members: group.members),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _BalancesTab(groupId: groupId),
                _ExpensesTab(groupId: groupId, group: group),
                _ActivityTab(groupId: groupId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Balances Tab
// ─────────────────────────────────────────────────────

class _BalancesTab extends ConsumerWidget {
  final String groupId;
  const _BalancesTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balancesAsync = ref.watch(groupBalancesProvider(groupId));
    final currentUserId = ref.watch(currentUserProvider)?.id ?? 'user_1';

    return balancesAsync.when(
      loading: () => ListView(
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SkeletonBox(
                width: double.infinity, height: 72, borderRadius: 14),
          ),
        ),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Error loading balances',
        subtitle: e.toString(),
      ),
      data: (summary) {
        if (summary.balances.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'All settled up!',
            subtitle: 'No outstanding balances in this group.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(groupBalancesProvider(groupId)),
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 100),
            children: [
              // Summary card
              _BalanceSummaryCard(summary: summary, isDark: isDark),
              const SizedBox(height: 12),
              ...summary.balances.map(
                (b) => BalanceTile(
                  balance: b,
                  groupId: groupId,
                  onSettleUp: b.fromUserId == currentUserId
                      ? () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useRootNavigator: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => SettleUpSheet(
                              balance: b,
                              groupId: groupId,
                            ),
                          )
                      : null,
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceSummaryCard extends ConsumerWidget {
  final dynamic summary;
  final bool isDark;

  const _BalanceSummaryCard({required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final net = summary.net as double;
    final isPositive = net >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [
                  AppColors.income.withValues(alpha: 0.15),
                  AppColors.income.withValues(alpha: 0.05),
                ]
              : [
                  AppColors.expense.withValues(alpha: 0.15),
                  AppColors.expense.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPositive
              ? AppColors.income.withValues(alpha: 0.3)
              : AppColors.expense.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? "You're owed overall" : "You owe overall",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currency${net.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isPositive ? AppColors.income : AppColors.expense,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniStat(
                label: "Lent",
                value: '$currency${(summary.totalLent as double).toStringAsFixed(0)}',
                color: AppColors.income,
              ),
              const SizedBox(height: 4),
              _MiniStat(
                label: "Borrowed",
                value: '$currency${(summary.totalOwed as double).toStringAsFixed(0)}',
                color: AppColors.expense,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

Future<void> _confirmDeleteExpense(
    BuildContext context, WidgetRef ref, String expenseId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Expense'),
      content: const Text(
          'Are you sure you want to delete this expense? This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => ctx.pop(false), child: const Text('Cancel')),
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
      await ref.read(groupApiServiceProvider).deleteExpense(expenseId);
      // groupId is encoded in the expense — invalidate via the provider family
      ref.invalidate(groupExpensesProvider);
      ref.invalidate(groupBalancesProvider);
      ref.invalidate(groupActivityProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Expense deleted'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.expense),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────
// Expenses Tab
// ─────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  final GroupModel group;
  const _ExpensesTab({required this.groupId, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));

    return expensesAsync.when(
      loading: () => ListView(
        children: List.generate(
          4,
          (_) => const SkeletonExpenseTile(),
        ),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load expenses',
        subtitle: e.toString(),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No expenses yet',
            subtitle: 'Add an expense to start tracking.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(groupExpensesProvider(groupId)),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: expenses.length,
            itemBuilder: (context, i) => ExpenseTile(
              expense: expenses[i],
              onEdit: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useRootNavigator: true,
                backgroundColor: Colors.transparent,
                builder: (_) => EditExpenseSheet(
                  expense: expenses[i],
                  group: group,
                ),
              ),
              onDelete: () =>
                  _confirmDeleteExpense(context, ref, expenses[i].id),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// Activity Tab
// ─────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  final String groupId;
  const _ActivityTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activityAsync = ref.watch(groupActivityProvider(groupId));

    return activityAsync.when(
      loading: () => ListView(
        children: List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SkeletonBox(
                width: double.infinity, height: 56, borderRadius: 12),
          ),
        ),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load activity',
        subtitle: e.toString(),
      ),
      data: (activities) {
        if (activities.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'No activity yet',
            subtitle: 'Activity will appear here as the group evolves.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(groupActivityProvider(groupId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: activities.length,
            itemBuilder: (context, i) =>
                _ActivityTile(activity: activities[i], isDark: isDark)
                    .animate(delay: (i * 40).ms)
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.05),
          ),
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityModel activity;
  final bool isDark;

  const _ActivityTile({required this.activity, required this.isDark});

  IconData _iconForType(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded:
        return Icons.add_circle_outline_rounded;
      case ActivityType.expenseDeleted:
        return Icons.delete_outline_rounded;
      case ActivityType.settlementCompleted:
        return Icons.check_circle_outline_rounded;
      case ActivityType.memberJoined:
        return Icons.person_add_alt_1_rounded;
      case ActivityType.memberRemoved:
        return Icons.person_remove_alt_1_rounded;
      case ActivityType.groupCreated:
        return Icons.group_add_rounded;
    }
  }

  Color _colorForType(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded:
        return AppColors.secondary;
      case ActivityType.expenseDeleted:
        return AppColors.expense;
      case ActivityType.settlementCompleted:
        return AppColors.income;
      case ActivityType.memberJoined:
        return AppColors.primary;
      case ActivityType.memberRemoved:
        return AppColors.warning;
      case ActivityType.groupCreated:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(activity.type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForType(activity.type), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM, h:mm a').format(activity.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          AvatarWidget(
            name: activity.userName,
            imageUrl: activity.userAvatar,
            size: 28,
          ),
        ],
      ),
    );
  }
}
