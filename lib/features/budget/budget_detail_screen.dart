import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../core/utils/category_app_icons.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/custom_category.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../transactions/widgets/edit_transaction_sheet.dart';
import 'add_budget_sheet.dart';

/// Budget detail — a single flat "hero" card (icon, amount, progress, stats,
/// date range) followed by the matching transaction list. No gradients, no
/// oversized ring — everything reuses the flat card language used across the
/// rest of the Budgets feature.
class BudgetDetailScreen extends ConsumerWidget {
  final String budgetId;

  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetProvider);
    final budget = budgets.cast<Budget?>().firstWhere(
          (b) => b?.id == budgetId,
          orElse: () => null,
        );

    if (budget == null) {
      return const Scaffold(
        body: Center(child: Text('Budget not found')),
      );
    }

    final spent = ref.watch(budgetSpentProvider(budgetId));
    final progress = ref.watch(budgetProgressProvider(budgetId));
    final status = ref.watch(budgetStatusProvider(budgetId));
    final transactions = ref.watch(budgetTransactionsProvider(budgetId));
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final remaining = (budget.amount - spent).clamp(0.0, double.infinity);
    final overspent = spent > budget.amount ? spent - budget.amount : 0.0;
    final statusColor = switch (status) {
      BudgetStatus.safe => AppColors.income,
      BudgetStatus.warning => AppColors.warning,
      BudgetStatus.exceeded => AppColors.expense,
    };

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _showMenu(context, ref, budget),
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                  ],
                ),
              ),
            ),

            // ── Hero card ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _HeroCard(
                  budget: budget,
                  spent: spent,
                  progress: progress,
                  status: status,
                  statusColor: statusColor,
                  remaining: remaining,
                  overspent: overspent,
                  currency: currency,
                  isDark: isDark,
                ),
              ),
            ),

            // ── Transactions header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: budget.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${transactions.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: budget.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Transaction list ──
            if (transactions.isEmpty)
              const SliverFillRemaining(
                child: _EmptyTransactions(),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _TransactionTile(
                    tx: transactions[i],
                    currency: currency,
                    isDark: isDark,
                  ),
                  childCount: transactions.length,
                ),
              ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 40 + MediaQuery.of(context).padding.bottom,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _EditBar(
        budget: budget,
        onEdit: () => _openEdit(context, budget),
        isDark: isDark,
      ),
    );
  }

  void _openEdit(BuildContext context, Budget budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddBudgetSheet(editBudgetId: budget.id),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref, Budget budget) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BudgetMenu(budget: budget, ref: ref, parentContext: context),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final double progress;
  final BudgetStatus status;
  final Color statusColor;
  final double remaining;
  final double overspent;
  final String currency;
  final bool isDark;

  const _HeroCard({
    required this.budget,
    required this.spent,
    required this.progress,
    required this.status,
    required this.statusColor,
    required this.remaining,
    required this.overspent,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final dividerColor = AppColors.textTertiary.withValues(alpha: 0.3);
    final range = budget.period.currentRange;
    final fmt = DateFormat('d MMM');
    final isOver = overspent > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? cardBg : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon, title, date range, % badge
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: budget.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(budget.icon, color: budget.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(budget.period.periodIcon,
                            color: AppColors.textSecondary, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${budget.period.label} · ${fmt.format(range.start)} – ${fmt.format(range.end)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PctBadge(progress: progress, color: statusColor),
            ],
          ),

          const SizedBox(height: 20),

          // Amount
          Text(
            CurrencyFormatter.format(spent, symbol: currency),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: statusColor,
              letterSpacing: -0.8,
            ),
          ),
          Text(
            'of ${CurrencyFormatter.format(budget.amount, symbol: currency)} budget',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Icon(
                status == BudgetStatus.exceeded
                    ? Icons.warning_rounded
                    : Icons.info_outline_rounded,
                size: 13,
                color: statusColor,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  isOver
                      ? '${CurrencyFormatter.format(overspent, symbol: currency)} over budget'
                      : '${CurrencyFormatter.format(remaining, symbol: currency)} remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                budget.period.nextResetLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Container(height: 0.5, color: dividerColor),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _StatCell(
                    label: 'Budget',
                    value: CurrencyFormatter.format(budget.amount,
                        symbol: currency),
                    color: budget.color),
              ),
              Container(width: 0.5, height: 32, color: dividerColor),
              Expanded(
                child: _StatCell(
                    label: 'Spent',
                    value: CurrencyFormatter.format(spent, symbol: currency),
                    color: AppColors.expense),
              ),
              Container(width: 0.5, height: 32, color: dividerColor),
              Expanded(
                child: _StatCell(
                    label: 'Left',
                    value:
                        CurrencyFormatter.format(remaining, symbol: currency),
                    color: AppColors.income),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PctBadge extends StatelessWidget {
  final double progress;
  final Color color;

  const _PctBadge({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0.0, 999.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${pct.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCell(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Transaction tile ─────────────────────────────────────────────────────────

class _TransactionTile extends ConsumerWidget {
  final Transaction tx;
  final String currency;
  final bool isDark;

  const _TransactionTile({
    required this.tx,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customCats = ref.watch(customCategoriesProvider);
    CustomCategory? customCat;
    if (tx.customCategoryId != null) {
      for (final c in customCats) {
        if (c.id == tx.customCategoryId) {
          customCat = c;
          break;
        }
      }
    }

    final color = customCat?.color ?? tx.category.color;
    final icon = customCat?.icon ?? tx.category.icon;
    final label = customCat?.label ?? tx.category.label;
    final titleText = (tx.note != null && tx.note!.trim().isNotEmpty) ? tx.note! : label;
    final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: Colors.transparent,
            builder: (_) => EditTransactionSheet(transaction: tx),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Expense brand icon if selected, otherwise category icon
                if (tx.appIcon != null && tx.appIcon!.isNotEmpty)
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 0.8,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        CategoryAppIcons.pathFor(tx.appIcon!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tx.note != null && tx.note!.trim().isNotEmpty
                            ? '$label · ${DateFormat('d MMM · h:mm a').format(tx.date)}'
                            : DateFormat('d MMM · h:mm a').format(tx.date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(tx.amount, symbol: currency),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty transactions ────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Expenses matching this budget will appear here',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit bottom bar ───────────────────────────────────────────────────────────

class _EditBar extends StatelessWidget {
  final Budget budget;
  final VoidCallback onEdit;
  final bool isDark;

  const _EditBar({
    required this.budget,
    required this.onEdit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Edit Budget',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: budget.color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Context menu sheet ────────────────────────────────────────────────────────

class _BudgetMenu extends ConsumerWidget {
  final Budget budget;
  final WidgetRef ref;
  final BuildContext parentContext;

  const _BudgetMenu({
    required this.budget,
    required this.ref,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _MenuTile(
              icon: budget.isArchived
                  ? Icons.unarchive_rounded
                  : Icons.archive_rounded,
              label: budget.isArchived ? 'Unarchive' : 'Archive',
              color: AppColors.warning,
              isDark: isDark,
              onTap: () async {
                Navigator.of(context).pop();
                final notifier = ref.read(budgetProvider.notifier);
                if (budget.isArchived) {
                  await notifier.unarchive(budget.id);
                } else {
                  await notifier.archive(budget.id);
                  if (parentContext.mounted) Navigator.of(parentContext).pop();
                }
              },
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.delete_rounded,
              label: 'Delete Budget',
              color: AppColors.expense,
              isDark: isDark,
              onTap: () async {
                final confirmed = await _confirmDelete(context);
                if (confirmed == true) {
                  if (context.mounted) Navigator.of(context).pop();
                  await ref.read(budgetProvider.notifier).delete(budget.id);
                  if (parentContext.mounted) Navigator.of(parentContext).pop();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete Budget'),
          content: Text(
              'Are you sure you want to delete "${budget.title}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
