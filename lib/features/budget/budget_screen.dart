import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/budget_provider.dart';
import '../../shared/widgets/app_search_bar.dart';
import '../../shared/widgets/empty_state.dart';
import 'add_budget_sheet.dart';
import 'widgets/budget_card.dart';
import 'widgets/budget_period_filter.dart';
import 'widgets/budget_summary_header.dart';

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
    final filtered = ref.watch(filteredBudgetsProvider);
    final activeBudgets = ref.watch(activeBudgetsProvider);
    final showArchived = ref.watch(showArchivedBudgetsProvider);

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
                  _Header(onAdd: () => _openAddSheet(context)),

                  const SizedBox(height: 20),

                  // ── Summary card (only when active budgets exist) ──
                  if (activeBudgets.isNotEmpty) ...[
                    const BudgetSummaryHeader(),
                    const SizedBox(height: 16),
                  ],

                  // ── Search ──
                  if (activeBudgets.isNotEmpty || showArchived)
                    AppSearchBar(
                      hintText: 'Search budgets...',
                      onChanged: (v) =>
                          ref.read(budgetSearchQueryProvider.notifier).state = v,
                    ),

                  // ── Archive toggle ──
                  if (activeBudgets.isNotEmpty || showArchived)
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
                  onAdd: () => _openAddSheet(context),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final budget = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: BudgetCard(
                        budget: budget,
                        animationIndex: i,
                        onTap: () => context.push('/budget/${budget.id}'),
                      ),
                    );
                  },
                  childCount: filtered.length,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.primary.withValues(alpha: 0.6),
                  width: 0.5,
                ),
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
    ).animate().fadeIn(duration: 400.ms);
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
    ).animate(delay: 150.ms).fadeIn(duration: 300.ms);
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyBudgets extends StatelessWidget {
  final bool isArchived;
  final VoidCallback onAdd;

  const _EmptyBudgets({required this.isArchived, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return isArchived
        ? const EmptyState(
            icon: Icons.archive_outlined,
            title: 'No archived budgets',
            subtitle: 'Budgets you archive will appear here',
          )
        : EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No budgets yet',
            subtitle:
                'Create your first budget to start tracking your spending goals',
            actionLabel: 'Create Budget',
            onAction: onAdd,
          );
  }
}
