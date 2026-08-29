import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/reminder_provider.dart';
import '../../providers/settings_provider.dart';
import '../add_transaction/add_transaction_sheet.dart';
import '../../shared/utils/guest_guard.dart';

void _openAddTransactionSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AddTransactionSheet(),
  );
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
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
                  _Header(),
                  const SizedBox(height: 28),
                  _SectionLabel(label: 'DAILY REMINDER'),
                  const SizedBox(height: 12),
                  const _DailyReminderCard(),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'RECURRING PAYMENTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => requireAuth(
                            context,
                            ref,
                            () => _openAddTransactionSheet(context),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 15, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                'Add',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const _RecurringSubtitle(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const _RecurringTransactionsList(),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60 + MediaQuery.of(context).padding.bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 14),
          Text(
            'Notifications',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _RecurringSubtitle extends StatelessWidget {
  const _RecurringSubtitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Get reminded before your recurring transactions are due.',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}

// ── Daily reminder card ───────────────────────────────────────────────────────

class _DailyReminderCard extends ConsumerWidget {
  const _DailyReminderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(dailyReminderProvider);
    final config = configAsync.valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = config?.enabled ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedContainer(
        duration: 300.ms,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? AppColors.income.withValues(alpha: 0.4)
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: enabled ? 1.2 : 0.5,
          ),
          boxShadow: enabled && !isDark
              ? [
                  BoxShadow(
                    color: AppColors.income.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.income.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.alarm_rounded,
                      color: AppColors.income,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Expense Log',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A daily nudge to add your transactions',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: configAsync.isLoading
                        ? null
                        : (v) => ref
                            .read(dailyReminderProvider.notifier)
                            .setEnabled(v),
                    activeThumbColor: AppColors.income,
                    activeTrackColor: AppColors.income.withValues(alpha: 0.4),
                  ),
                ],
              ),
              if (enabled) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Remind me at',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    _TimePickerButton(
                      time: config!.time,
                      color: AppColors.income,
                      onPick: (picked) => ref
                          .read(dailyReminderProvider.notifier)
                          .setTime(picked),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05);
  }
}

// ── Recurring transactions list ───────────────────────────────────────────────

class _RecurringTransactionsList extends ConsumerWidget {
  const _RecurringTransactionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(recurringReminderEntriesProvider);

    if (entries.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkCard
                      : AppColors.lightCard,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.repeat_rounded,
                  size: 32,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No recurring transactions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add a recurring transaction (monthly, weekly…)\nand it will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => requireAuth(
                  context,
                  ref,
                  () => _openAddTransactionSheet(context),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Transaction'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => _RecurringReminderCard(
          entry: entries[i],
          index: i,
        ),
        childCount: entries.length,
      ),
    );
  }
}

class _RecurringReminderCard extends ConsumerWidget {
  final RecurringReminderEntry entry;
  final int index;
  const _RecurringReminderCard({required this.entry, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tx = entry.transaction;
    final config = entry.config;
    final currency = ref.watch(currencyProvider);
    final enabled = config.enabled;

    final amountStr = CurrencyFormatter.format(tx.amount, symbol: currency);
    final recurrenceLabel = tx.recurrence.label;
    final categoryLabel = tx.customCategoryId != null
        ? (ref
                .read(customCategoriesProvider)
                .cast<dynamic>()
                .firstWhere((c) => c.id == tx.customCategoryId,
                    orElse: () => null)
                ?.label as String? ??
            tx.category.label)
        : tx.category.label;

    final displayName = tx.note?.isNotEmpty == true ? tx.note! : categoryLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: AnimatedContainer(
        duration: 250.ms,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? AppColors.warning.withValues(alpha: 0.4)
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: enabled ? 1.2 : 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + title + toggle
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.repeat_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$recurrenceLabel · $amountStr',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) => ref
                        .read(transactionRemindersProvider.notifier)
                        .setEnabled(tx, v),
                    activeThumbColor: AppColors.warning,
                    activeTrackColor: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ],
              ),

              if (enabled) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Days before row
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded,
                        size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Remind me',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    _DaysBeforePicker(
                      value: config.daysBefore,
                      onChanged: (v) => ref
                          .read(transactionRemindersProvider.notifier)
                          .setDaysBefore(tx, v),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Time row
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'At',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    _TimePickerButton(
                      time: config.time,
                      color: AppColors.warning,
                      onPick: (picked) => ref
                          .read(transactionRemindersProvider.notifier)
                          .setTime(tx, picked),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 60).ms).fadeIn().slideY(begin: 0.05);
  }
}

// ── Days before picker ────────────────────────────────────────────────────────

class _DaysBeforePicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DaysBeforePicker({required this.value, required this.onChanged});

  static const _options = [
    (0, 'Same day'),
    (1, '1 day before'),
    (2, '2 days before'),
    (3, '3 days before'),
    (5, '5 days before'),
    (7, '1 week before'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = _options.firstWhere(
      (o) => o.$1 == value,
      orElse: () => (value, '$value days before'),
    );

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.$2,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: AppColors.warning),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Remind me',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.textLight,
                ),
              ),
            ),
            for (final (days, label) in _options)
              ListTile(
                title: Text(label, style: const TextStyle(fontSize: 14)),
                trailing: value == days
                    ? Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 20)
                    : null,
                onTap: () {
                  onChanged(days);
                  Navigator.pop(context);
                },
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ── Time picker button ────────────────────────────────────────────────────────

class _TimePickerButton extends StatelessWidget {
  final TimeOfDay time;
  final Color color;
  final ValueChanged<TimeOfDay> onPick;

  const _TimePickerButton({
    required this.time,
    required this.color,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked =
            await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              time.format(context),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
