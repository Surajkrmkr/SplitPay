import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/ad_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/budget_provider.dart';
import '../../providers/home_widget_sync_provider.dart';
import '../../shared/widgets/app_ad_banner.dart';
import '../../shared/widgets/app_search_bar.dart';
import '../../shared/widgets/empty_state.dart';
import 'add_budget_sheet.dart';
import 'widgets/budget_card.dart';
import 'widgets/budget_period_filter.dart';
import 'widgets/budget_summary_header.dart';
import '../../shared/utils/guest_guard.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  void _openAddSheet(BuildContext context, {String? budgetId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddBudgetSheet(editBudgetId: budgetId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBudgets = ref.watch(budgetProvider);
    final filtered = ref.watch(filteredBudgetsProvider);
    final activeBudgets = ref.watch(activeBudgetsProvider);
    final showArchived = ref.watch(showArchivedBudgetsProvider);
    final canReorder = !showArchived &&
        ref.watch(budgetPeriodFilterProvider) == BudgetPeriodFilter.all &&
        ref.watch(budgetSearchQueryProvider).trim().isEmpty;
    // Keeps the Overall Budget home-screen widget fresh whenever this screen
    // (where budgets are created/edited) is visited.
    ref.watch(homeWidgetSyncProvider);
    final hasAnyBudgets = allBudgets.isNotEmpty;
    final hasArchivedBudgets = allBudgets.any((b) => b.isArchived);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Header ──
                  _Header(
                      onAdd: () => requireAuth(
                          context, ref, () => _openAddSheet(context))),

                  const SizedBox(height: 20),

                  // ── Summary card (only when active budgets exist) ──
                  if (activeBudgets.isNotEmpty) ...[
                    const BudgetSummaryHeader(),
                    const AppAdBanner(
                      placement: AdPlacement.budgetSummaryBanner,
                      margin: EdgeInsets.fromLTRB(20, 16, 20, 0),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Search ──
                  if (hasAnyBudgets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: AppSearchBar(
                        hintText: 'Search budgets...',
                        onChanged: (v) => ref
                            .read(budgetSearchQueryProvider.notifier)
                            .state = v,
                      ),
                    ),

                  // ── Archive toggle ──
                  if (hasAnyBudgets)
                    _ArchiveToggle(showArchived: showArchived, ref: ref),

                  // ── Period filter — always show when active budgets exist
                  // so users can switch back after a filter yields zero results.
                  if (!showArchived && activeBudgets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const BudgetFilterChips(),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Budget list or empty state ──
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: _EmptyBudgets(
                  isArchived: showArchived,
                  hasArchivedBudgets: hasArchivedBudgets,
                  onAdd: () =>
                      requireAuth(context, ref, () => _openAddSheet(context)),
                  onViewArchived: () => ref
                      .read(showArchivedBudgetsProvider.notifier)
                      .state = true,
                ),
              )
            else if (showArchived)
              // Archived budgets stay as a single-column list.
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final budget = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: BudgetCard(
                          budget: budget,
                          onTap: () => context.push('/budget/${budget.id}'),
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              )
            else
              // Keyed tiles retain their identity and animate into new slots.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 14.0;
                      final cardWidth = (constraints.maxWidth - spacing) / 2;
                      final cardHeight = cardWidth / 0.82;
                      final rowCount = (filtered.length + 1) ~/ 2;
                      final gridHeight =
                          rowCount * cardHeight + (rowCount - 1) * spacing;

                      return SizedBox(
                        height: gridHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: filtered.asMap().entries.map((entry) {
                            final index = entry.key;
                            final budget = entry.value;
                            final card = BudgetCard(
                              budget: budget,
                              compact: true,
                              onTap: () => context.push('/budget/${budget.id}'),
                            );
                            final child = !canReorder
                                ? card
                                : DragTarget<String>(
                                    onWillAcceptWithDetails: (details) =>
                                        details.data != budget.id,
                                    onAcceptWithDetails: (details) => ref
                                        .read(budgetProvider.notifier)
                                        .reorderActive(details.data, budget.id),
                                    builder: (context, candidates, rejected) {
                                      final isDropTarget =
                                          candidates.isNotEmpty;
                                      return AnimatedScale(
                                        scale: isDropTarget ? 0.97 : 1,
                                        duration:
                                            const Duration(milliseconds: 160),
                                        curve: Curves.easeOutBack,
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 160),
                                          foregroundDecoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: isDropTarget
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: LongPressDraggable<String>(
                                            data: budget.id,
                                            feedback: Transform.scale(
                                              scale: 1.04,
                                              child: Material(
                                                color: Colors.transparent,
                                                elevation: 14,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                child: SizedBox(
                                                  width: cardWidth,
                                                  child: BudgetCard(
                                                    budget: budget,
                                                    compact: true,
                                                    onTap: () {},
                                                  ),
                                                ),
                                              ),
                                            ),
                                            childWhenDragging: AnimatedOpacity(
                                              opacity: 0.25,
                                              duration: const Duration(
                                                  milliseconds: 160),
                                              child: card,
                                            ),
                                            child: card,
                                          ),
                                        ),
                                      );
                                    },
                                  );

                            return AnimatedPositioned(
                              key: ValueKey(budget.id),
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOutCubic,
                              left: (index % 2) * (cardWidth + spacing),
                              top: (index ~/ 2) * (cardHeight + spacing),
                              width: cardWidth,
                              height: cardHeight,
                              child: child,
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 100 + MediaQuery.of(context).padding.bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onAdd;
  const _Header({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Budget',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          // Add-budget action — mirrors the chip styling used by AppBackButton
          // so it sits visually right next to the header title.
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onAdd();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'New',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
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

// ── Archive toggle ───────────────────────────────────────────────────────────

class _ArchiveToggle extends StatelessWidget {
  final bool showArchived;
  final WidgetRef ref;

  const _ArchiveToggle({
    required this.showArchived,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            showArchived ? 'Archived Budgets' : 'Active Budgets',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(showArchivedBudgetsProvider.notifier).state =
                  !showArchived;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showArchived ? Icons.inbox_rounded : Icons.archive_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    showArchived ? 'Active' : 'Archived',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
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

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyBudgets extends StatelessWidget {
  final bool isArchived;
  final bool hasArchivedBudgets;
  final VoidCallback onAdd;
  final VoidCallback onViewArchived;

  const _EmptyBudgets({
    required this.isArchived,
    required this.hasArchivedBudgets,
    required this.onAdd,
    required this.onViewArchived,
  });

  @override
  Widget build(BuildContext context) {
    if (isArchived) {
      return const EmptyState(
        icon: Icons.archive_outlined,
        title: 'No archived budgets',
        subtitle: 'Budgets you archive will appear here',
      );
    }

    if (hasArchivedBudgets) {
      return EmptyState(
        icon: Icons.archive_outlined,
        title: 'All budgets archived',
        subtitle:
            'All your budgets are currently archived. View them in Archived Budgets or create a new one.',
        actionLabel: 'View Archived Budgets',
        onAction: onViewArchived,
      );
    }

    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'No budgets yet',
      subtitle:
          'Create your first budget to start tracking your spending goals',
      actionLabel: 'Create Budget',
      onAction: onAdd,
    );
  }
}
