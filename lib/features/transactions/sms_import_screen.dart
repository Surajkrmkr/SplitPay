import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/parsed_sms_transaction.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/sms_reader_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sms_import_provider.dart';

class SmsImportScreen extends ConsumerWidget {
  const SmsImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(smsImportProvider);
    final notifier = ref.read(smsImportProvider.notifier);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SMS Import',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          _SyncButton(
            isSyncing: state.isSyncing,
            isGranted: state.permissionState == SmsPermissionState.granted,
            onPressed: () => notifier.syncMessages(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.errorMessage != null)
              _ErrorBanner(message: state.errorMessage!),

            if (state.permissionState != SmsPermissionState.granted)
              _PermissionCard(
                permissionState: state.permissionState,
                onRequest: () => notifier.requestPermissionAndFetch(),
              ),

            if (state.permissionState == SmsPermissionState.granted) ...[
              _StatsHeaderBar(
                state: state,
                onSelectAll: (select) => notifier.selectAll(select),
              ),
              Expanded(
                child: state.isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : state.transactions.isEmpty
                        ? _EmptyState(
                            isSyncing: state.isSyncing,
                            onSync: () => notifier.syncMessages(),
                          )
                        : _buildGroupedList(
                            context, ref, state, isDark, currency, notifier),
              ),
            ],
          ],
        ),
      ),
      bottomSheet: (state.permissionState == SmsPermissionState.granted &&
              state.selectedCount > 0)
          ? _BottomImportBar(
              selectedCount: state.selectedCount,
              isDark: isDark,
              onImport: () async {
                final imported = await notifier.importSelected();
                if (context.mounted && imported > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Imported $imported transaction${imported > 1 ? 's' : ''} to Personal Expenses!',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.income,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
            )
          : null,
    );
  }

  void _showCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    String txId,
    Category currentCat,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Select Category',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: Category.values.map((cat) {
                final isSelected = cat == currentCat;
                return ChoiceChip(
                  avatar: Icon(
                    cat.icon,
                    size: 16,
                    color: isSelected ? Colors.white : cat.color,
                  ),
                  label: Text(cat.label),
                  selected: isSelected,
                  selectedColor: cat.color,
                  backgroundColor: cat.color.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : cat.color,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(smsImportProvider.notifier)
                          .updateCategory(txId, cat);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    WidgetRef ref,
    SmsImportState state,
    bool isDark,
    String currency,
    SmsImportNotifier notifier,
  ) {
    // Build a flat list of either a String (date header label) or a
    // ParsedSmsTransaction (card). This avoids nested ListViews.
    final items = <Object>[];
    String? lastLabel;

    for (final tx in state.transactions) {
      final label = _dayLabel(tx.date);
      if (label != lastLabel) {
        items.add(label);
        lastLabel = label;
      }
      items.add(tx);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        if (item is String) {
          return _DateHeader(label: item);
        }
        final tx = item as ParsedSmsTransaction;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SmsTransactionCard(
            tx: tx,
            isDark: isDark,
            currency: currency,
            onToggle: () => notifier.toggleSelection(tx.id),
            onCategoryTap: () =>
                _showCategoryPicker(context, ref, tx.id, tx.category),
          ),
        );
      },
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(txDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date); // e.g. Monday
    return DateFormat('d MMM yyyy').format(date);
  }
}

// ── Date group header ─────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: isDark ? AppColors.textSecondary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 0.5,
              color: (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  final bool isSyncing;
  final bool isGranted;
  final VoidCallback onPressed;

  const _SyncButton({
    required this.isSyncing,
    required this.isGranted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: (isSyncing || !isGranted) ? null : onPressed,
      icon: isSyncing
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : const Icon(Icons.sync_rounded, size: 18),
      label: Text(
        isSyncing ? 'Syncing...' : 'Sync SMS',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final SmsPermissionState permissionState;
  final VoidCallback onRequest;

  const _PermissionCard({
    required this.permissionState,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (permissionState == SmsPermissionState.unsupported) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.warning, size: 40),
            const SizedBox(height: 12),
            const Text(
              'SMS Inbox Sync Notice',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Automatic SMS inbox reading is supported on Android devices. On iOS, you can paste bank SMS text directly when adding a transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sms_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'SMS Reading Permission',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 8),
          const Text(
            'Grant permission to automatically detect bank and UPI transaction alerts from your SMS inbox and import them as personal expenses.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: permissionState == SmsPermissionState.permanentlyDenied
                  ? () => openAppSettings()
                  : onRequest,
              icon: Icon(
                permissionState == SmsPermissionState.permanentlyDenied
                    ? Icons.settings_rounded
                    : Icons.security_rounded,
                size: 18,
              ),
              label: Text(
                permissionState == SmsPermissionState.permanentlyDenied
                    ? 'Open Device Settings'
                    : 'Grant SMS Permission',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}

class _StatsHeaderBar extends StatelessWidget {
  final SmsImportState state;
  final ValueChanged<bool> onSelectAll;

  const _StatsHeaderBar({
    required this.state,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final allUnimportedSelected =
        state.unimportedCount > 0 && state.selectedCount == state.unimportedCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${state.transactions.length} detected • ${state.unimportedCount} unimported',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (state.unimportedCount > 0)
            TextButton(
              onPressed: () => onSelectAll(!allUnimportedSelected),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                allUnimportedSelected ? 'Deselect All' : 'Select All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmsTransactionCard extends StatefulWidget {
  final ParsedSmsTransaction tx;
  final bool isDark;
  final String currency;
  final VoidCallback onToggle;
  final VoidCallback onCategoryTap;

  const _SmsTransactionCard({
    required this.tx,
    required this.isDark,
    required this.currency,
    required this.onToggle,
    required this.onCategoryTap,
  });

  @override
  State<_SmsTransactionCard> createState() => _SmsTransactionCardState();
}

class _SmsTransactionCardState extends State<_SmsTransactionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isExpense = widget.tx.type == TransactionType.expense;
    final typeColor = isExpense ? AppColors.expense : AppColors.income;

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.tx.isSelected && !widget.tx.isImported
              ? AppColors.primary.withValues(alpha: 0.5)
              : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: widget.tx.isSelected && !widget.tx.isImported ? 1.5 : 0.8,
        ),
        boxShadow: widget.tx.isSelected && !widget.tx.isImported
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.tx.isImported ? null : widget.onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Checkbox(
                    value: widget.tx.isImported ? true : widget.tx.isSelected,
                    onChanged: widget.tx.isImported
                        ? null
                        : (_) => widget.onToggle(),
                    activeColor: widget.tx.isImported
                        ? AppColors.textTertiary
                        : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExpense
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: typeColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.tx.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: widget.tx.isImported
                                      ? AppColors.textSecondary
                                      : (widget.isDark
                                          ? Colors.white
                                          : AppColors.textLight),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.tx.isImported)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.income.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_rounded,
                                        size: 12, color: AppColors.income),
                                    SizedBox(width: 4),
                                    Text(
                                      'Imported',
                                      style: TextStyle(
                                        color: AppColors.income,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                DateFormat('MMM d, h:mm a')
                                    .format(widget.tx.date),
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: InkWell(
                                onTap: widget.tx.isImported
                                    ? null
                                    : widget.onCategoryTap,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.tx.category.color
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        widget.tx.category.icon,
                                        size: 12,
                                        color: widget.tx.category.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          widget.tx.category.label,
                                          style: TextStyle(
                                            color: widget.tx.category.color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${isExpense ? '-' : '+'}${CurrencyFormatter.format(widget.tx.amount, symbol: widget.currency)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: typeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          onPressed: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          icon: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 22,
                            color: AppColors.textTertiary,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          splashRadius: 20,
                          tooltip: _isExpanded ? 'Collapse' : 'View SMS',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.tx.body,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: widget.isDark
                        ? AppColors.textSecondary
                        : AppColors.textLightSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback onSync;

  const _EmptyState({
    required this.isSyncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Transaction SMS Found',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 8),
            const Text(
              'We searched your SMS inbox for bank & UPI debit/credit notifications but found no new relevant messages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: isSyncing ? null : onSync,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Sync Latest Messages'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.expense.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.expense, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.expense,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomImportBar extends StatelessWidget {
  final int selectedCount;
  final bool isDark;
  final VoidCallback onImport;

  const _BottomImportBar({
    required this.selectedCount,
    required this.isDark,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.download_rounded, size: 20),
          label: Text(
            'Import $selectedCount Transaction${selectedCount > 1 ? 's' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
