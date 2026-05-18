import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../shared/widgets/empty_state.dart';
import 'widgets/edit_transaction_sheet.dart';
import 'widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(),
            _SearchBar(),
            _FilterChips(),
            Expanded(child: _TransactionList()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            'Transactions',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

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

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  static const _filters = [
    (TransactionFilter.all, 'All'),
    (TransactionFilter.today, 'Today'),
    (TransactionFilter.week, 'Week'),
    (TransactionFilter.month, 'Month'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(filterProvider);

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkCard
                        : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
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

class _TransactionList extends ConsumerWidget {
  const _TransactionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(searchedTransactionsProvider);

    if (transactions.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions found',
        subtitle: ref.watch(searchQueryProvider).isNotEmpty
            ? 'Try a different search term'
            : 'No transactions for the selected period',
      );
    }

    // Group by date
    final grouped = <String, List<_IndexedTx>>{};
    var globalIndex = 0;
    for (final tx in transactions) {
      final key = _dateKey(tx.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(_IndexedTx(tx, globalIndex++));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: grouped.length,
      itemBuilder: (context, i) {
        final key = grouped.keys.elementAt(i);
        final txs = grouped[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(label: key),
            ...txs.map((item) => TransactionTile(
                  transaction: item.tx,
                  index: item.index,
                  onDelete: () =>
                      ref.read(transactionProvider.notifier).delete(item.tx.id),
                  onEdit: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        EditTransactionSheet(transaction: item.tx),
                  ),
                )),
          ],
        );
      },
    );
  }

  String _dateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _IndexedTx {
  final Transaction tx;
  final int index;
  const _IndexedTx(this.tx, this.index);
}

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
      ),
    );
  }
}
