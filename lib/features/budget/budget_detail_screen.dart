import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../transactions/widgets/edit_transaction_sheet.dart';
import 'add_budget_sheet.dart';

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
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Collapsible header ──
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            leadingWidth: 56,
            leading: const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Center(child: AppBackButton()),
            ),
            actions: [
              IconButton(
                onPressed: () => _showMenu(context, ref, budget),
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _DetailHero(
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

          // ── Stats row ──
          SliverToBoxAdapter(
            child: _StatsRow(
              budget: budget,
              spent: spent,
              remaining: remaining,
              currency: currency,
              isDark: isDark,
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1),
          ),

          // ── Period info ──
          SliverToBoxAdapter(
            child: _PeriodInfo(budget: budget, isDark: isDark)
                .animate(delay: 150.ms)
                .fadeIn()
                .slideY(begin: 0.1),
          ),

          // ── Transactions header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
            ).animate(delay: 200.ms).fadeIn(),
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
                ).animate(delay: (220 + i * 40).ms).fadeIn().slideX(
                      begin: 0.05,
                      curve: Curves.easeOutCubic,
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
      backgroundColor: Colors.transparent,
      builder: (_) => AddBudgetSheet(editBudgetId: budget.id),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref, Budget budget) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BudgetMenu(budget: budget, ref: ref),
    );
  }
}

// ── Hero section with progress ring ─────────────────────────────────────────

class _DetailHero extends StatelessWidget {
  final Budget budget;
  final double spent;
  final double progress;
  final BudgetStatus status;
  final Color statusColor;
  final double remaining;
  final double overspent;
  final String currency;
  final bool isDark;

  const _DetailHero({
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            budget.color.withValues(alpha: 0.18),
            budget.color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Title + period
          Text(
            budget.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textLight,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: budget.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(budget.period.periodIcon, color: budget.color, size: 12),
                const SizedBox(width: 5),
                Text(
                  budget.period.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: budget.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Progress ring
          TweenAnimationBuilder<double>(
            duration: 1000.ms,
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => _ProgressRing(
              progress: value,
              color: statusColor,
              budget: budget,
              spent: spent,
              remaining: remaining,
              overspent: overspent,
              currency: currency,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final Budget budget;
  final double spent;
  final double remaining;
  final double overspent;
  final String currency;
  final bool isDark;

  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.overspent,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = overspent > 0;

    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _ArcPainter(
              progress: progress,
              bgColor: color.withValues(alpha: 0.12),
              fgColor: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOver ? Icons.warning_rounded : budget.icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isOver
                      ? CurrencyFormatter.format(overspent, symbol: currency)
                      : CurrencyFormatter.format(remaining, symbol: currency),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                isOver ? 'over budget' : 'remaining',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(progress * 100).clamp(0.0, 999.0).toStringAsFixed(0)}% used',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;

  const _ArcPainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = fgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    const fullSweep = 2 * math.pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fullSweep,
      false,
      bgPaint,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fullSweep * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Budget budget;
  final double spent;
  final double remaining;
  final String currency;
  final bool isDark;

  const _StatsRow({
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
                label: 'Budget',
                value:
                    CurrencyFormatter.format(budget.amount, symbol: currency),
                color: budget.color),
          ),
          _Divider(),
          Expanded(
            child: _StatCell(
                label: 'Spent',
                value: CurrencyFormatter.format(spent, symbol: currency),
                color: AppColors.expense),
          ),
          _Divider(),
          Expanded(
            child: _StatCell(
                label: 'Left',
                value: CurrencyFormatter.format(remaining, symbol: currency),
                color: AppColors.income),
          ),
        ],
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 0.5,
        height: 32,
        color: AppColors.textTertiary.withValues(alpha: 0.3),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

// ── Period info ───────────────────────────────────────────────────────────────

class _PeriodInfo extends StatelessWidget {
  final Budget budget;
  final bool isDark;

  const _PeriodInfo({required this.budget, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final range = budget.period.currentRange;
    final fmt = DateFormat('d MMM yyyy');
    final bgColor = isDark ? AppColors.darkCard : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(budget.period.periodIcon, color: budget.color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${fmt.format(range.start)} – ${fmt.format(range.end)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textLight,
              ),
            ),
          ),
          Text(
            budget.period.nextResetLabel,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction tile ─────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  final String currency;
  final bool isDark;

  const _TransactionTile({
    required this.tx,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = tx.category.color;
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
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tx.category.icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.note ?? tx.category.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMM · h:mm a').format(tx.date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
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

  const _BudgetMenu({required this.budget, required this.ref});

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
                  if (context.mounted) Navigator.of(context).pop();
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
                Navigator.of(context).pop();
                final confirmed = await _confirmDelete(context);
                if (confirmed == true) {
                  await ref.read(budgetProvider.notifier).delete(budget.id);
                  if (context.mounted) Navigator.of(context).pop();
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
        builder: (_) => AlertDialog(
          title: const Text('Delete Budget'),
          content: Text(
              'Are you sure you want to delete "${budget.title}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
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
