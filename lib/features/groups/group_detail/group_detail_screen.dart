import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/ad_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/app_ad_banner.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/models/group_expense_model.dart';
import '../../../data/models/group_model.dart';
import '../../../data/models/settlement_model.dart';
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

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_isSearching && _tabController.index != 1) _closeSearch();
      if (mounted) setState(() {});
    });
    _searchCtrl.addListener(() {
      _searchNotifier.value = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchNotifier.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    setState(() => _isSearching = false);
    _searchCtrl.clear();
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));

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
            const SkeletonBox(
                width: double.infinity, height: 56, borderRadius: 14),
            const SizedBox(height: 20),
            const SkeletonBox(
                width: double.infinity, height: 140, borderRadius: 16),
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
          subtitle: friendlyErrorMessage(e),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(groupDetailProvider(widget.groupId)),
        ),
      ),
      data: (group) => Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isSearching
                    ? const SizedBox.shrink()
                    : Text(
                        group.name,
                        key: const ValueKey('gname'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              actions: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isSearching
                      ? const SizedBox.shrink()
                      : Container(
                          key: const ValueKey('actions'),
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _AppBarIconBtn(
                                icon: Icons.people_alt_rounded,
                                tooltip: 'Invite',
                                onTap: () => context
                                    .push('/groups/${widget.groupId}/invite'),
                                isDark: isDark,
                              ),
                              Container(
                                width: 0.5,
                                height: 20,
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                              ),
                              _AppBarIconBtn(
                                icon: Icons.tune_rounded,
                                tooltip: 'Settings',
                                onTap: () => context
                                    .push('/groups/${widget.groupId}/settings'),
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
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
                  Tab(text: 'Total'),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _GroupInfoBar(
                group: group,
                isSearching: _isSearching,
                searchCtrl: _searchCtrl,
                searchFocus: _searchFocus,
                isExpensesTab: _tabController.index == 1,
                hasExpenses: ref
                        .watch(groupExpensesProvider(widget.groupId))
                        .valueOrNull
                        ?.isNotEmpty ==
                    true,
                onSearchOpen: _openSearch,
                onSearchClose: _closeSearch,
                isDark: isDark,
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _BalancesTab(groupId: widget.groupId),
              _ExpensesTab(
                groupId: widget.groupId,
                group: group,
                searchNotifier: _searchNotifier,
              ),
              _ActivityTab(groupId: widget.groupId),
              _TotalTab(groupId: widget.groupId),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group info bar — avatars + description ↔ expandable search field
// ─────────────────────────────────────────────────────────────────────────────

class _GroupInfoBar extends StatelessWidget {
  final GroupModel group;
  final bool isSearching;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final bool isExpensesTab;
  final bool hasExpenses;
  final VoidCallback onSearchOpen;
  final VoidCallback onSearchClose;
  final bool isDark;

  const _GroupInfoBar({
    required this.group,
    required this.isSearching,
    required this.searchCtrl,
    required this.searchFocus,
    required this.isExpensesTab,
    required this.hasExpenses,
    required this.onSearchOpen,
    required this.onSearchClose,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.lightBg,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final isSearch = child.key == const ValueKey('sf');
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(isSearch ? 0.06 : -0.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: isSearching
              ? _SearchField(
                  key: const ValueKey('sf'),
                  controller: searchCtrl,
                  focusNode: searchFocus,
                  onClose: onSearchClose,
                  isDark: isDark,
                )
              : _InfoRow(
                  key: const ValueKey('ir'),
                  group: group,
                  isExpensesTab: isExpensesTab,
                  hasExpenses: hasExpenses,
                  onSearchOpen: onSearchOpen,
                  isDark: isDark,
                ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final GroupModel group;
  final bool isExpensesTab;
  final bool hasExpenses;
  final VoidCallback onSearchOpen;
  final bool isDark;

  const _InfoRow({
    super.key,
    required this.group,
    required this.isExpensesTab,
    required this.hasExpenses,
    required this.onSearchOpen,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MemberAvatarRow(
          members: group.members,
          maxVisible: 4,
          avatarSize: 28,
        ),
        const SizedBox(width: 10),
        if (group.description?.isNotEmpty == true)
          Expanded(
            child: Text(
              group.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          )
        else
          const Spacer(),
        if (isExpensesTab && hasExpenses) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSearchOpen,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.search_rounded,
                size: 17,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textLightSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClose;
  final bool isDark;

  const _SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onClose,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.textLight,
            ),
            decoration: InputDecoration(
              hintText: 'Search expenses...',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, val, __) => val.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.textSecondary,
                        onPressed: controller.clear,
                      ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            ),
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: onClose,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
        onRefresh: () async {
          ref.invalidate(groupDetailProvider(groupId));
          ref.invalidate(groupBalancesProvider(groupId));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error loading balances',
              subtitle: friendlyErrorMessage(e),
            ),
          ],
        ),
      ),
      data: (summary) {
        if (summary.balances.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(groupDetailProvider(groupId));
              ref.invalidate(groupBalancesProvider(groupId));
            },
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
          onRefresh: () async {
            ref.invalidate(groupDetailProvider(groupId));
            ref.invalidate(groupBalancesProvider(groupId));
          },
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
    final isSettled = net == 0;
    final isPositive = net >= 0;
    final accentColor = isSettled
        ? AppColors.primary
        : (isPositive ? AppColors.income : AppColors.expense);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.18),
            accentColor.withValues(alpha: 0.04),
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
                    isSettled
                        ? Icons.check_circle_outline_rounded
                        : (isPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded),
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSettled
                          ? "You're all settled up"
                          : (isPositive
                              ? "You're owed overall"
                              : "You owe overall"),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isSettled)
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────
// Expenses Tab
// ─────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerStatefulWidget {
  final String groupId;
  final GroupModel group;
  final ValueNotifier<String> searchNotifier;

  const _ExpensesTab({
    required this.groupId,
    required this.group,
    required this.searchNotifier,
  });

  @override
  ConsumerState<_ExpensesTab> createState() => _ExpensesTabState();
}

enum _ExpenseDateFilter { all, week, month }

enum _ExpenseSortOrder { newestFirst, oldestFirst, highestAmount, lowestAmount }

class _ExpensesTabState extends ConsumerState<_ExpensesTab> {
  _ExpenseDateFilter _dateFilter = _ExpenseDateFilter.month;
  _ExpenseSortOrder _sort = _ExpenseSortOrder.newestFirst;
  Set<String> _payerFilter = {};
  double? _amountMin;
  double? _amountMax;

  @override
  void initState() {
    super.initState();
    widget.searchNotifier.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchNotifier.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  int get _activeFilterCount {
    int c = 0;
    if (_sort != _ExpenseSortOrder.newestFirst) c++;
    if (_payerFilter.isNotEmpty) c++;
    if (_amountMin != null || _amountMax != null) c++;
    return c;
  }

  List<GroupExpenseModel> _applyFilters(List<GroupExpenseModel> expenses) {
    var result = expenses;

    // Date range
    if (_dateFilter != _ExpenseDateFilter.all) {
      final now = DateTime.now();
      final cutoff = _dateFilter == _ExpenseDateFilter.week
          ? now.subtract(const Duration(days: 7))
          : DateTime(now.year, now.month, 1);
      result = result.where((e) => e.date.isAfter(cutoff)).toList();
    }

    // Payer
    if (_payerFilter.isNotEmpty) {
      result =
          result.where((e) => _payerFilter.contains(e.paidById)).toList();
    }

    // Amount range
    if (_amountMin != null) {
      result = result.where((e) => e.amount >= _amountMin!).toList();
    }
    if (_amountMax != null) {
      result = result.where((e) => e.amount <= _amountMax!).toList();
    }

    // Search (query comes from the parent's expandable search field)
    final query = widget.searchNotifier.value;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.paidByName.toLowerCase().contains(q) ||
            (e.notes?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // Sort
    result = List.from(result);
    switch (_sort) {
      case _ExpenseSortOrder.newestFirst:
        result.sort((a, b) => b.date.compareTo(a.date));
      case _ExpenseSortOrder.oldestFirst:
        result.sort((a, b) => a.date.compareTo(b.date));
      case _ExpenseSortOrder.highestAmount:
        result.sort((a, b) => b.amount.compareTo(a.amount));
      case _ExpenseSortOrder.lowestAmount:
        result.sort((a, b) => a.amount.compareTo(b.amount));
    }

    return result;
  }

  void _showFilterSheet(
      BuildContext context, List<GroupExpenseModel> expenses) {
    final payerNames = <String, String>{};
    for (final e in expenses) {
      payerNames[e.paidById] = e.paidByName;
    }
    final allPayers = payerNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final maxAmount = expenses.isEmpty
        ? 50000.0
        : expenses.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    final sliderMax =
        ((maxAmount / 1000).ceil() * 1000).toDouble().clamp(1000.0, 1000000.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseFilterSheet(
        currentSort: _sort,
        currentPayers: _payerFilter,
        currentAmountMin: _amountMin,
        currentAmountMax: _amountMax,
        allPayers: allPayers,
        sliderMax: sliderMax,
        onApply: ({
          required _ExpenseSortOrder sort,
          required Set<String> payers,
          required double? amountMin,
          required double? amountMax,
        }) {
          setState(() {
            _sort = sort;
            _payerFilter = payers;
            _amountMin = amountMin;
            _amountMax = amountMax;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expensesAsync = ref.watch(groupExpensesProvider(widget.groupId));

    return expensesAsync.when(
      loading: () => ListView(
        children: List.generate(4, (_) => const SkeletonExpenseTile()),
      ),
      error: (e, _) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(groupDetailProvider(widget.groupId));
          ref.invalidate(groupExpensesProvider(widget.groupId));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load expenses',
              subtitle: friendlyErrorMessage(e),
            ),
          ],
        ),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(groupDetailProvider(widget.groupId));
              ref.invalidate(groupExpensesProvider(widget.groupId));
            },
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

        final filtered = _applyFilters(expenses);
        final activeCount = _activeFilterCount;
        final payerNameById = <String, String>{
          for (final e in expenses) e.paidById: e.paidByName,
        };

        return Column(
          children: [
            // ── Date chips + Filter button in one row ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  // Date period chips (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (f, label) in [
                            (_ExpenseDateFilter.all, 'All'),
                            (_ExpenseDateFilter.month, 'This Month'),
                            (_ExpenseDateFilter.week, 'This Week'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _dateFilter = f),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _dateFilter == f
                                        ? AppColors.primary
                                        : isDark
                                            ? AppColors.darkCard
                                            : AppColors.lightCard,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _dateFilter == f
                                          ? AppColors.primary
                                          : isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder,
                                      width: _dateFilter == f ? 1.0 : 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: _dateFilter == f
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: _dateFilter == f
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filter button
                  GestureDetector(
                    onTap: () => _showFilterSheet(context, expenses),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: activeCount > 0
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : isDark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: activeCount > 0
                                  ? AppColors.primary
                                  : isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                              width: activeCount > 0 ? 1.0 : 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded,
                                  size: 15,
                                  color: activeCount > 0
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Filter',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: activeCount > 0
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (activeCount > 0)
                          Positioned(
                            top: -5,
                            right: -5,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$activeCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Active filter chips ─────────────────────────────────────
            if (activeCount > 0)
              SizedBox(
                height: 32,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (_sort != _ExpenseSortOrder.newestFirst)
                      _ActiveChip(
                        label: switch (_sort) {
                          _ExpenseSortOrder.oldestFirst => 'Oldest first',
                          _ExpenseSortOrder.highestAmount => 'Highest amount',
                          _ExpenseSortOrder.lowestAmount => 'Lowest amount',
                          _ExpenseSortOrder.newestFirst => '',
                        },
                        onRemove: () => setState(
                            () => _sort = _ExpenseSortOrder.newestFirst),
                      ),
                    for (final payerId in _payerFilter)
                      _ActiveChip(
                        label: payerNameById[payerId] ?? payerId,
                        onRemove: () => setState(() {
                          _payerFilter = Set.from(_payerFilter)
                            ..remove(payerId);
                        }),
                      ),
                    if (_amountMin != null || _amountMax != null)
                      _ActiveChip(
                        label: _amountMin != null && _amountMax != null
                            ? '${_amountMin!.toStringAsFixed(0)} – ${_amountMax!.toStringAsFixed(0)}'
                            : _amountMin != null
                                ? '≥ ${_amountMin!.toStringAsFixed(0)}'
                                : '≤ ${_amountMax!.toStringAsFixed(0)}',
                        onRemove: () =>
                            setState(() => _amountMin = _amountMax = null),
                      ),
                  ],
                ),
              ),

            // ── Expense list ────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(groupDetailProvider(widget.groupId));
                  ref.invalidate(groupExpensesProvider(widget.groupId));
                },
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          EmptyState(
                            icon: Icons.search_off_rounded,
                            title: activeCount > 0 ||
                                    widget.searchNotifier.value.isNotEmpty
                                ? 'No expenses match'
                                : 'No expenses yet',
                            subtitle: activeCount > 0 ||
                                    widget.searchNotifier.value.isNotEmpty
                                ? 'Try adjusting your filters.'
                                : 'Add an expense to start tracking.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => ExpenseTile(
                          expense: filtered[i],
                          onEdit: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useRootNavigator: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => EditExpenseSheet(
                              expense: filtered[i],
                              group: widget.group,
                            ),
                          ),
                          onDelete: () => _confirmDeleteExpense(
                              context, ref, filtered[i].id),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// Expense filter sheet
// ─────────────────────────────────────────────────────

class _ExpenseFilterSheet extends StatefulWidget {
  final _ExpenseSortOrder currentSort;
  final Set<String> currentPayers;
  final double? currentAmountMin;
  final double? currentAmountMax;
  final List<MapEntry<String, String>> allPayers;
  final double sliderMax;
  final void Function({
    required _ExpenseSortOrder sort,
    required Set<String> payers,
    required double? amountMin,
    required double? amountMax,
  }) onApply;

  const _ExpenseFilterSheet({
    required this.currentSort,
    required this.currentPayers,
    required this.currentAmountMin,
    required this.currentAmountMax,
    required this.allPayers,
    required this.sliderMax,
    required this.onApply,
  });

  @override
  State<_ExpenseFilterSheet> createState() => _ExpenseFilterSheetState();
}

class _ExpenseFilterSheetState extends State<_ExpenseFilterSheet> {
  late _ExpenseSortOrder _sort;
  late Set<String> _payers;
  late double _sliderMin;
  late double _sliderMax;

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _payers = Set.from(widget.currentPayers);
    _sliderMin = widget.currentAmountMin ?? 0;
    _sliderMax = widget.currentAmountMax ?? widget.sliderMax;
  }

  bool get _hasChanges =>
      _sort != _ExpenseSortOrder.newestFirst ||
      _payers.isNotEmpty ||
      _sliderMin > 0 ||
      _sliderMax < widget.sliderMax;

  void _reset() {
    setState(() {
      _sort = _ExpenseSortOrder.newestFirst;
      _payers = {};
      _sliderMin = 0;
      _sliderMax = widget.sliderMax;
    });
  }

  void _apply() {
    widget.onApply(
      sort: _sort,
      payers: _payers,
      amountMin: _sliderMin > 0 ? _sliderMin : null,
      amountMax: _sliderMax < widget.sliderMax ? _sliderMax : null,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Text(
                      'Filter & Sort',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    if (_hasChanges)
                      TextButton(
                        onPressed: _reset,
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                              color: AppColors.expense,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  children: [
                    // Sort
                    _SheetSection(
                      title: 'Sort by',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (s, label) in [
                            (_ExpenseSortOrder.newestFirst, 'Newest first'),
                            (_ExpenseSortOrder.oldestFirst, 'Oldest first'),
                            (_ExpenseSortOrder.highestAmount, 'Highest amount'),
                            (_ExpenseSortOrder.lowestAmount, 'Lowest amount'),
                          ])
                            _FilterChip(
                              label: label,
                              selected: _sort == s,
                              onTap: () => setState(() => _sort = s),
                              isDark: isDark,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Paid by
                    if (widget.allPayers.length > 1) ...[
                      _SheetSection(
                        title: 'Paid by',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in widget.allPayers)
                              _FilterChip(
                                label: entry.value,
                                selected: _payers.contains(entry.key),
                                onTap: () => setState(() {
                                  if (_payers.contains(entry.key)) {
                                    _payers.remove(entry.key);
                                  } else {
                                    _payers.add(entry.key);
                                  }
                                }),
                                isDark: isDark,
                                color: AppColors.secondary,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Amount range
                    _SheetSection(
                      title: 'Amount range',
                      child: Column(
                        children: [
                          RangeSlider(
                            values: RangeValues(_sliderMin, _sliderMax),
                            min: 0,
                            max: widget.sliderMax,
                            divisions: 20,
                            activeColor: AppColors.primary,
                            inactiveColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            onChanged: (v) => setState(() {
                              _sliderMin = v.start;
                              _sliderMax = v.end;
                            }),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _AmountBound(
                                  label: 'Min',
                                  value: _sliderMin.toStringAsFixed(0)),
                              _AmountBound(
                                  label: 'Max',
                                  value: _sliderMax.toStringAsFixed(0)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Apply
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _apply,
                    child: const Text(
                      'Apply Filters',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// Shared filter sheet sub-widgets (scoped to this file)
// ─────────────────────────────────────────────────────

class _SheetSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : isDark
                  ? AppColors.darkCard
                  : const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  size: 13, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountBound extends StatelessWidget {
  final String label;
  final String value;
  const _AmountBound({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary)),
      ],
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
        onRefresh: () async {
          ref.invalidate(groupDetailProvider(groupId));
          ref.invalidate(groupActivityProvider(groupId));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load activity',
              subtitle: friendlyErrorMessage(e),
            ),
          ],
        ),
      ),
      data: (activities) {
        if (activities.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(groupDetailProvider(groupId));
              ref.invalidate(groupActivityProvider(groupId));
            },
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
          onRefresh: () async {
            ref.invalidate(groupDetailProvider(groupId));
            ref.invalidate(groupActivityProvider(groupId));
          },
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
        color: (isUpi ? AppColors.secondary : AppColors.primary)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isUpi ? AppColors.secondary : AppColors.primary)
              .withValues(alpha: 0.3),
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
                  child:
                      Icon(_iconForType(activity.type), size: 18, color: color),
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

// ─────────────────────────────────────────────────────
// Total Tab — total spend + your share, charted by month
// ─────────────────────────────────────────────────────

class _TotalTab extends ConsumerWidget {
  final String groupId;
  const _TotalTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? 'user_1';
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));

    return expensesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load totals',
        subtitle: friendlyErrorMessage(e),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return const EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'Nothing to total yet',
            subtitle: 'Add an expense to see spending totals for this group.',
          );
        }

        final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
        final yourShare = expenses.fold<double>(
            0, (sum, e) => sum + e.shareForUser(currentUserId));

        // Bucket by month, chronological, most recent 6 months with data.
        final byMonth = <DateTime, double>{};
        for (final e in expenses) {
          final key = DateTime(e.date.year, e.date.month);
          byMonth[key] = (byMonth[key] ?? 0) + e.amount;
        }
        final months = byMonth.keys.toList()..sort();
        final recentMonths =
            months.length > 6 ? months.sublist(months.length - 6) : months;
        final maxVal = recentMonths
            .map((m) => byMonth[m]!)
            .fold<double>(0, (a, b) => a > b ? a : b);
        final chartMax = maxVal == 0 ? 100.0 : maxVal * 1.25;

        final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
        final borderColor =
            isDark ? AppColors.darkBorder : AppColors.lightBorder;
        final gridColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Total Spent',
                    value: '$currency${totalSpent.toStringAsFixed(0)}',
                    color: AppColors.secondary,
                    icon: Icons.groups_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    label: 'Your Share',
                    value: '$currency${yourShare.toStringAsFixed(0)}',
                    color: AppColors.primary,
                    icon: Icons.person_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Spend',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        maxY: chartMax,
                        minY: 0,
                        barGroups: recentMonths.asMap().entries.map((entry) {
                          final i = entry.key;
                          final month = entry.value;
                          final val = byMonth[month]!;
                          final isLatest = i == recentMonths.length - 1;
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: val == 0 ? 0.5 : val,
                                color: isLatest
                                    ? AppColors.primary
                                    : AppColors.secondary
                                        .withValues(alpha: 0.6),
                                width: 24,
                                borderRadius: BorderRadius.circular(6),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: chartMax,
                                  color: isDark
                                      ? AppColors.darkElevated
                                      : AppColors.lightCard,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= recentMonths.length) {
                                  return const SizedBox.shrink();
                                }
                                final isLatest = i == recentMonths.length - 1;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    DateFormat('MMM').format(recentMonths[i]),
                                    style: TextStyle(
                                      color: isLatest
                                          ? AppColors.primary
                                          : AppColors.textTertiary,
                                      fontSize: 11,
                                      fontWeight: isLatest
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: chartMax / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: gridColor,
                            strokeWidth: 0.5,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) =>
                                isDark ? AppColors.darkElevated : Colors.white,
                            tooltipRoundedRadius: 8,
                            getTooltipItem:
                                (group, groupIndex, rod, rodIndex) =>
                                    BarTooltipItem(
                              '$currency${rod.toY.toStringAsFixed(0)}',
                              const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      swapAnimationDuration: 600.ms,
                      swapAnimationCurve: Curves.easeInOutCubic,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AppAdBanner(
              placement: AdPlacement.groupDetailsTotalBanner,
              margin: EdgeInsets.zero,
            ),
          ],
        );
      },
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
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textLightSecondary,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${settlements.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700),
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
              isUpi
                  ? Icons.account_balance_wallet_rounded
                  : Icons.check_circle_rounded,
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
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary),
                    ),
                    if (settlement.transactionId != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${settlement.transactionId!.length > 12 ? settlement.transactionId!.substring(0, 12) : settlement.transactionId!}…',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textTertiary),
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
                  border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3), width: 0.8),
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
