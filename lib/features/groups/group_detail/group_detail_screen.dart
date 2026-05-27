import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/models/group_model.dart';
import '../../../data/models/settlement_model.dart';
import '../../../data/services/group_api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/app_back_button.dart';
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
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          leadingWidth: 56,
          leading: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Center(child: AppBackButton()),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          children: [
            const SkeletonBox(width: 180, height: 22, borderRadius: 6),
            const SizedBox(height: 12),
            const SkeletonBox(width: double.infinity, height: 56, borderRadius: 14),
            const SizedBox(height: 20),
            const SkeletonBox(width: double.infinity, height: 140, borderRadius: 16),
            const SizedBox(height: 16),
            ...List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: SkeletonExpenseTile(),
              ),
            ),
          ],
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
                leadingWidth: 56,
                leading: const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Center(child: AppBackButton()),
                ),
                title: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AppBarIconBtn(
                          icon: Icons.people_alt_rounded,
                          tooltip: 'Invite',
                          onTap: () => context.push('/groups/$groupId/invite'),
                          isDark: isDark,
                        ),
                        Container(
                          width: 0.5,
                          height: 20,
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                        ),
                        _AppBarIconBtn(
                          icon: Icons.tune_rounded,
                          tooltip: 'Settings',
                          onTap: () => context.push('/groups/$groupId/settings'),
                          isDark: isDark,
                        ),
                      ],
                    ),
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
      error: (e, _) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(groupBalancesProvider(groupId)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error loading balances',
              subtitle: e.toString(),
            ),
          ],
        ),
      ),
      data: (summary) {
        if (summary.balances.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(groupBalancesProvider(groupId)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'All settled up!',
                  subtitle: 'No outstanding balances in this group.',
                ),
              ],
            ),
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
              const SizedBox(height: 12),
              _SettlementsSection(groupId: groupId, isDark: isDark),
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
    final accentColor = isPositive ? AppColors.income : AppColors.expense;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [
                  AppColors.income.withValues(alpha: 0.18),
                  AppColors.income.withValues(alpha: 0.04),
                ]
              : [
                  AppColors.expense.withValues(alpha: 0.18),
                  AppColors.expense.withValues(alpha: 0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPositive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPositive ? "You're owed overall" : "You owe overall",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$currency${net.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 0.5,
              color: accentColor.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Total Lent',
                    value:
                        '$currency${(summary.totalLent as double).toStringAsFixed(0)}',
                    color: AppColors.income,
                    icon: Icons.arrow_upward_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    label: 'Total Borrowed',
                    value:
                        '$currency${(summary.totalOwed as double).toStringAsFixed(0)}',
                    color: AppColors.expense,
                    icon: Icons.arrow_downward_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      error: (e, _) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(groupExpensesProvider(groupId)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load expenses',
              subtitle: e.toString(),
            ),
          ],
        ),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(groupExpensesProvider(groupId)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No expenses yet',
                  subtitle: 'Add an expense to start tracking.',
                ),
              ],
            ),
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
                width: double.infinity, height: 72, borderRadius: 12),
          ),
        ),
      ),
      error: (e, _) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(groupActivityProvider(groupId)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load activity',
              subtitle: e.toString(),
            ),
          ],
        ),
      ),
      data: (activities) {
        if (activities.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(groupActivityProvider(groupId)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No activity yet',
                  subtitle: 'Activity will appear here as the group evolves.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(groupActivityProvider(groupId)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: activities.length,
            itemBuilder: (context, i) => _ActivityTile(
              activity: activities[i],
              isDark: isDark,
              isLast: i == activities.length - 1,
            )
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
  final bool isLast;

  const _ActivityTile({
    required this.activity,
    required this.isDark,
    this.isLast = false,
  });

  IconData _iconForType(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded:
        return Icons.receipt_long_rounded;
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

  Widget? _paymentBadge() {
    if (activity.type != ActivityType.settlementCompleted) return null;
    final method = activity.metadata?['paymentMethod'] as String?;
    if (method == null) return null;
    final isUpi = method.toUpperCase() == 'UPI';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (isUpi ? AppColors.secondary : AppColors.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isUpi ? AppColors.secondary : AppColors.primary).withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Text(
        isUpi ? 'UPI' : 'Manual',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isUpi ? AppColors.secondary : AppColors.primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(activity.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(_iconForType(activity.type), size: 18, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Content card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : AppColors.textLight,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              DateFormat('d MMM, h:mm a')
                                  .format(activity.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            if (_paymentBadge() != null) ...[
                              const SizedBox(width: 6),
                              _paymentBadge()!,
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      AvatarWidget(
                        name: activity.userName,
                        imageUrl: activity.userAvatar,
                        size: 30,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activity.userName.split(' ').first,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  const _AppBarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              icon,
              size: 18,
              color: isDark ? AppColors.textSecondary : AppColors.textLightSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settlement History Section (shown at the bottom of the Balances tab)
// ─────────────────────────────────────────────────────────────────────────────

class _SettlementsSection extends ConsumerWidget {
  final String groupId;
  final bool isDark;

  const _SettlementsSection({required this.groupId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final settlementsAsync = ref.watch(groupSettlementsProvider(groupId));

    return settlementsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (settlements) {
        if (settlements.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Recent Settlements',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${settlements.length}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...settlements.take(5).map((s) => _SettlementTile(
                  settlement: s,
                  currency: currency,
                  isDark: isDark,
                )),
          ],
        );
      },
    );
  }
}

class _SettlementTile extends StatelessWidget {
  final SettlementModel settlement;
  final String currency;
  final bool isDark;

  const _SettlementTile({
    required this.settlement,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isUpi = settlement.isUpiPayment;
    final badgeColor = isUpi ? AppColors.secondary : AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Method icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUpi ? Icons.account_balance_wallet_rounded : Icons.check_circle_rounded,
              color: badgeColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${settlement.payerName} → ${settlement.payeeName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      DateFormat('d MMM, h:mm a').format(settlement.settledAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                    ),
                    if (settlement.transactionId != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${settlement.transactionId!.length > 12 ? settlement.transactionId!.substring(0, 12) : settlement.transactionId!}…',
                        style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount + badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currency${settlement.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.income,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Text(
                  isUpi ? 'UPI' : 'Manual',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
