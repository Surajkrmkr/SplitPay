import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/constants/ad_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_ad_banner.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../shared/widgets/empty_state.dart';
import 'sms_import_screen.dart';
import 'widgets/edit_transaction_sheet.dart';
import 'widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            const _SearchBar(),
            const _PeriodChips(),
            const _ActiveFiltersRow(),
            const Expanded(child: _TransactionList()),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = ref.watch(activeFilterCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Transactions',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          // Filter & Sort button
          GestureDetector(
            onTap: () => _showFilterSheet(context, ref),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: activeCount > 0
                        ? primary.withValues(alpha: 0.12)
                        : (isDark
                            ? cardBg
                            : AppColors.lightCard),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: activeCount > 0
                          ? primary
                          : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                      width: activeCount > 0 ? 1.0 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: activeCount > 0
                            ? primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: activeCount > 0
                              ? primary
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
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Import from SMS',
              child: IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SmsImportScreen(),
                  ),
                ),
                icon: const Icon(Icons.sms_rounded, size: 20),
                color: primary,
                style: IconButton.styleFrom(
                  backgroundColor: primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FilterSheet(),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: TextField(
        onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
        decoration: InputDecoration(
          hintText: 'Search transactions...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: Consumer(
            builder: (context, ref, _) {
              final query = ref.watch(searchQueryProvider);
              if (query.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () =>
                    ref.read(searchQueryProvider.notifier).state = '',
              );
            },
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1);
  }
}

// ── Period chips (All / Today / Week / Month) ─────────────────────────────────

class _PeriodChips extends ConsumerWidget {
  const _PeriodChips();

  static const _filters = [
    (TransactionFilter.all, 'All'),
    (TransactionFilter.today, 'Today'),
    (TransactionFilter.week, 'Week'),
    (TransactionFilter.month, 'Month'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(filterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (filter, label) = _filters[i];
          final isSelected = selected == filter;

          return GestureDetector(
            onTap: () => ref.read(filterProvider.notifier).state = filter,
            child: AnimatedContainer(
              duration: 200.ms,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary
                    : isDark
                        ? cardBg
                        : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? primary
                      : isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    ).animate(delay: 150.ms).fadeIn();
  }
}

// ── Active filters row ────────────────────────────────────────────────────────

class _ActiveFiltersRow extends ConsumerWidget {
  const _ActiveFiltersRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(transactionTypeFilterProvider);
    final sort = ref.watch(transactionSortProvider);
    final categories = ref.watch(categoryFilterProvider);
    final amount = ref.watch(amountRangeProvider);
    final currency = ref.watch(currencyProvider);

    final chips = <(String label, VoidCallback onRemove)>[];

    if (sort != TransactionSortOrder.newestFirst) {
      final label = switch (sort) {
        TransactionSortOrder.oldestFirst => 'Oldest first',
        TransactionSortOrder.highestAmount => 'Highest amount',
        TransactionSortOrder.lowestAmount => 'Lowest amount',
        TransactionSortOrder.newestFirst => '',
      };
      chips.add((
        label,
        () => ref.read(transactionSortProvider.notifier).state =
            TransactionSortOrder.newestFirst,
      ));
    }

    if (type != TransactionTypeFilter.all) {
      chips.add((
        type == TransactionTypeFilter.income ? 'Income' : 'Expense',
        () => ref.read(transactionTypeFilterProvider.notifier).state =
            TransactionTypeFilter.all,
      ));
    }

    for (final cat in categories) {
      final label = _categoryLabel(cat, ref);
      chips.add((
        label,
        () {
          final current = Set<String>.from(ref.read(categoryFilterProvider));
          current.remove(cat);
          ref.read(categoryFilterProvider.notifier).state = current;
        },
      ));
    }

    if (amount.isActive) {
      final minStr = amount.min != null
          ? CurrencyFormatter.format(amount.min!, symbol: currency)
          : '';
      final maxStr = amount.max != null
          ? CurrencyFormatter.format(amount.max!, symbol: currency)
          : '';
      final label = amount.min != null && amount.max != null
          ? '$minStr – $maxStr'
          : amount.min != null
              ? '≥ $minStr'
              : '≤ $maxStr';
      chips.add((
        label,
        () =>
            ref.read(amountRangeProvider.notifier).state = const AmountRange(),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, onRemove) = chips[i];
          return _ActiveChip(label: label, onRemove: onRemove);
        },
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  String _categoryLabel(String key, WidgetRef ref) {
    try {
      return Category.values.byName(key).label;
    } catch (_) {
      final custom = ref.read(customCategoriesProvider);
      return custom
          .firstWhere((c) => c.id == key, orElse: () => throw '')
          .label;
    }
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  // Local copies — committed on close, allowing "Reset" to clear everything.
  late TransactionSortOrder _sort;
  late TransactionTypeFilter _type;
  late Set<String> _categories;
  late AmountRange _amount;
  double _sliderMin = 0;
  double _sliderMax = 50000;

  @override
  void initState() {
    super.initState();
    _sort = ref.read(transactionSortProvider);
    _type = ref.read(transactionTypeFilterProvider);
    _categories = Set.from(ref.read(categoryFilterProvider));
    _amount = ref.read(amountRangeProvider);
  }

  void _apply() {
    ref.read(transactionSortProvider.notifier).state = _sort;
    ref.read(transactionTypeFilterProvider.notifier).state = _type;
    ref.read(categoryFilterProvider.notifier).state = _categories;
    ref.read(amountRangeProvider.notifier).state = _amount;
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _sort = TransactionSortOrder.newestFirst;
      _type = TransactionTypeFilter.all;
      _categories = {};
      _amount = const AmountRange();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkSurface;

    final sliderCeil = ref.watch(maxTransactionAmountProvider);
    final currency = ref.watch(currencyProvider);
    final customCats = ref.watch(customCategoriesProvider);

    _sliderMin = _amount.min ?? 0;
    _sliderMax = _amount.max ?? sliderCeil;

    final hasChanges = _sort != TransactionSortOrder.newestFirst ||
        _type != TransactionTypeFilter.all ||
        _categories.isNotEmpty ||
        _amount.isActive;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? cardBg : Colors.white,
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
              // Title row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    if (hasChanges)
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
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  children: [
                    // ── Sort by ──────────────────────────────────────────────
                    _SheetSection(
                      title: 'Sort by',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (s, label) in [
                            (TransactionSortOrder.newestFirst, 'Newest first'),
                            (TransactionSortOrder.oldestFirst, 'Oldest first'),
                            (
                              TransactionSortOrder.highestAmount,
                              'Highest amount'
                            ),
                            (
                              TransactionSortOrder.lowestAmount,
                              'Lowest amount'
                            ),
                          ])
                            _ChoiceChip(
                              label: label,
                              selected: _sort == s,
                              onTap: () => setState(() => _sort = s),
                              isDark: isDark,
                              color: primary,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Type ─────────────────────────────────────────────────
                    _SheetSection(
                      title: 'Type',
                      child: Row(
                        children: [
                          for (final (t, label, color) in [
                            (
                              TransactionTypeFilter.all,
                              'All',
                              primary,
                            ),
                            (
                              TransactionTypeFilter.income,
                              'Income',
                              AppColors.income
                            ),
                            (
                              TransactionTypeFilter.expense,
                              'Expense',
                              AppColors.expense
                            ),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ChoiceChip(
                                label: label,
                                selected: _type == t,
                                onTap: () => setState(() => _type = t),
                                isDark: isDark,
                                color: color,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Categories ───────────────────────────────────────────
                    _SheetSection(
                      title: 'Categories',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cat in Category.values)
                            _CategoryChip(
                              label: cat.label,
                              icon: cat.icon,
                              color: cat.color,
                              selected: _categories.contains(cat.name),
                              onTap: () => setState(() {
                                if (_categories.contains(cat.name)) {
                                  _categories.remove(cat.name);
                                } else {
                                  _categories.add(cat.name);
                                }
                              }),
                              isDark: isDark,
                            ),
                          for (final cat in customCats)
                            _CategoryChip(
                              label: cat.label,
                              icon: cat.icon,
                              color: cat.color,
                              selected: _categories.contains(cat.id),
                              onTap: () => setState(() {
                                if (_categories.contains(cat.id)) {
                                  _categories.remove(cat.id);
                                } else {
                                  _categories.add(cat.id);
                                }
                              }),
                              isDark: isDark,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Amount range ─────────────────────────────────────────
                    _SheetSection(
                      title: 'Amount range',
                      child: Column(
                        children: [
                          RangeSlider(
                            values: RangeValues(_sliderMin, _sliderMax),
                            min: 0,
                            max: sliderCeil,
                            divisions: 20,
                            activeColor: primary,
                            inactiveColor:
                                primary.withValues(alpha: 0.15),
                            onChanged: (v) {
                              setState(() {
                                _sliderMin = v.start;
                                _sliderMax = v.end;
                                _amount = AmountRange(
                                  min: v.start > 0 ? v.start : null,
                                  max: v.end < sliderCeil ? v.end : null,
                                );
                              });
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _AmountLabel(
                                  label: 'Min',
                                  value: CurrencyFormatter.format(_sliderMin,
                                      symbol: currency)),
                              _AmountLabel(
                                  label: 'Max',
                                  value: CurrencyFormatter.format(_sliderMax,
                                      symbol: currency)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Apply button
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
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

// ── Filter sheet sub-widgets ──────────────────────────────────────────────────

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
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final Color? color;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    final cardBg = Theme.of(context).cardTheme.color ?? AppColors.darkCard;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? effectiveColor.withValues(alpha: 0.12)
              : isDark
                  ? cardBg
                  : const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? effectiveColor
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: selected ? color : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_rounded, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  final String label;
  final String value;
  const _AmountLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary),
        ),
      ],
    );
  }
}

// ── Transaction list ──────────────────────────────────────────────────────────

class _TransactionList extends ConsumerWidget {
  const _TransactionList();

  static const _undoWindow = Duration(seconds: 3);

  void _handleSwipeDelete(BuildContext context, WidgetRef ref, Transaction tx) {
    // Scheduled on the app-scoped pendingDeletesProvider (not this widget's
    // own state) so the delete still commits on schedule even if the user
    // navigates away before the undo window elapses.
    ref
        .read(pendingDeletesProvider.notifier)
        .schedule(tx, undoWindow: _undoWindow);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.delete_outline_rounded,
                color: AppColors.expense, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text('Transaction deleted')),
          ],
        ),
        duration: _undoWindow,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () =>
              ref.read(pendingDeletesProvider.notifier).undo(tx.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(searchedTransactionsProvider);
    final currency = ref.watch(currencyProvider);

    if (transactions.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(transactionProvider.notifier).syncAndReload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions found',
              subtitle: ref.watch(searchQueryProvider).isNotEmpty
                  ? 'Try a different search term'
                  : 'Pull down to sync or add a transaction',
            ),
          ],
        ),
      );
    }

    // Group by date only when sorting by date; otherwise show flat list.
    final sort = ref.watch(transactionSortProvider);
    final isDateSort = sort == TransactionSortOrder.newestFirst ||
        sort == TransactionSortOrder.oldestFirst;

    if (!isDateSort) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(transactionProvider.notifier).syncAndReload(),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: transactions.length,
          itemBuilder: (context, i) {
            final tx = transactions[i];
            final showAd = (i + 1) % 4 == 0;
            final tile = TransactionTile(
              transaction: tx,
              onDelete: () => _handleSwipeDelete(context, ref, tx),
              onEdit: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useRootNavigator: true,
                backgroundColor: Colors.transparent,
                builder: (_) => EditTransactionSheet(transaction: tx),
              ),
            );
            if (!showAd) return tile;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tile,
                const AppAdBanner(
                  placement: AdPlacement.transactionsListBanner,
                  adSize: AdSize.mediumRectangle,
                  margin: EdgeInsets.symmetric(vertical: 12),
                ),
              ],
            );
          },
        ),
      );
    }

    // Date-grouped list
    final grouped = <String, List<Transaction>>{};
    final dayNet = <String, double>{};
    for (final tx in transactions) {
      final key = _dateKey(tx.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
      dayNet[key] = (dayNet[key] ?? 0) +
          (tx.type == TransactionType.income ? tx.amount : -tx.amount);
    }

    final keys = grouped.keys.toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(transactionProvider.notifier).syncAndReload(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: keys.length,
        itemBuilder: (context, groupIdx) {
          final key = keys[groupIdx];
          final items = grouped[key]!;

          int runningTxCount = 0;
          for (int g = 0; g < groupIdx; g++) {
            runningTxCount += grouped[keys[g]]!.length;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateHeader(
                label: key,
                total: dayNet[key] ?? 0,
                currency: currency,
              ),
              ...items.asMap().entries.map(
                (entry) {
                  final idx = entry.key;
                  final tx = entry.value;
                  final globalIdx = runningTxCount + idx + 1;
                  final showAd = globalIdx % 4 == 0;
                  final tile = TransactionTile(
                    transaction: tx,
                    onDelete: () => _handleSwipeDelete(context, ref, tx),
                    onEdit: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useRootNavigator: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EditTransactionSheet(transaction: tx),
                    ),
                  );
                  if (!showAd) return tile;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      tile,
                      const AppAdBanner(
                        placement: AdPlacement.transactionsListBanner,
                        adSize: AdSize.mediumRectangle,
                        margin: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _dateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return '${date.day} ${_monthAbbr(date.month)} ${date.year}';
  }

  String _monthAbbr(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];
}

class _DateHeader extends StatelessWidget {
  final String label;
  final double total;
  final String currency;
  const _DateHeader({
    required this.label,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpense = total < 0;
    final amountColor = total == 0
        ? (isDark ? AppColors.textSecondary : AppColors.textLightSecondary)
        : (isDark ? AppColors.textSecondary : AppColors.textLightSecondary);
    final prefix = total == 0 ? '' : (isExpense ? '-' : '+');

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textLightSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Text(
            '$prefix${CurrencyFormatter.format(total.abs(), symbol: currency)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
