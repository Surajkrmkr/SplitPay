import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/app_logger.dart';
import '../data/models/transaction_model.dart';
import '../data/services/reminder_service.dart';
import 'transaction_provider.dart';

const _tag = 'ReminderProvider';

// ── Keys ──────────────────────────────────────────────────────────────────────

const _kDailyEnabled = 'reminder_daily_enabled';
const _kDailyHour = 'reminder_daily_hour';
const _kDailyMinute = 'reminder_daily_minute';

// JSON-encoded map of transactionId → {enabled, daysBefore, hour, minute}
const _kTransactionReminders = 'reminder_transactions_v1';

// ── Daily reminder ────────────────────────────────────────────────────────────

class DailyReminderConfig {
  final bool enabled;
  final TimeOfDay time;

  const DailyReminderConfig({required this.enabled, required this.time});

  DailyReminderConfig copyWith({bool? enabled, TimeOfDay? time}) =>
      DailyReminderConfig(
        enabled: enabled ?? this.enabled,
        time: time ?? this.time,
      );
}

class DailyReminderNotifier extends AsyncNotifier<DailyReminderConfig> {
  @override
  Future<DailyReminderConfig> build() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyReminderConfig(
      enabled: prefs.getBool(_kDailyEnabled) ?? false,
      time: TimeOfDay(
        hour: prefs.getInt(_kDailyHour) ?? 21,
        minute: prefs.getInt(_kDailyMinute) ?? 0,
      ),
    );
  }

  Future<void> setEnabled(bool value) async {
    final log = AppLogger.instance;
    log.i('setEnabled($value) called', tag: _tag);
    final current = state.valueOrNull;
    if (current == null) {
      log.w('setEnabled: state not loaded yet, aborting', tag: _tag);
      return;
    }
    log.i('Current config: enabled=${current.enabled} '
        'time=${current.time.hour}:${current.time.minute.toString().padLeft(2, '0')}',
        tag: _tag);
    final updated = current.copyWith(enabled: value);
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDailyEnabled, value);
    log.i('Persisted enabled=$value to SharedPreferences', tag: _tag);
    if (value) {
      log.i('Calling scheduleDailyReminder at '
          '${updated.time.hour}:${updated.time.minute.toString().padLeft(2, '0')}',
          tag: _tag);
      await ReminderService.instance
          .scheduleDailyReminder(updated.time.hour, updated.time.minute);
    } else {
      log.i('Cancelling daily reminder', tag: _tag);
      await ReminderService.instance.cancelDailyReminder();
    }
    log.i('setEnabled($value) done', tag: _tag);
  }

  Future<void> setTime(TimeOfDay time) async {
    final log = AppLogger.instance;
    log.i('setTime(${time.hour}:${time.minute.toString().padLeft(2, '0')}) called',
        tag: _tag);
    final current = state.valueOrNull;
    if (current == null) {
      log.w('setTime: state not loaded yet, aborting', tag: _tag);
      return;
    }
    final updated = current.copyWith(time: time);
    state = AsyncData(updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDailyHour, time.hour);
    await prefs.setInt(_kDailyMinute, time.minute);
    log.i('Persisted new time to SharedPreferences', tag: _tag);
    if (updated.enabled) {
      log.i('Re-scheduling after time change', tag: _tag);
      await ReminderService.instance
          .scheduleDailyReminder(time.hour, time.minute);
    } else {
      log.i('Reminder is disabled — skipping reschedule', tag: _tag);
    }
  }
}

final dailyReminderProvider =
    AsyncNotifierProvider<DailyReminderNotifier, DailyReminderConfig>(
  DailyReminderNotifier.new,
);

// ── Per-transaction recurring reminder ───────────────────────────────────────

class TransactionReminderConfig {
  final bool enabled;
  final int daysBefore; // 0 = same day, 1 = 1 day before, etc.
  final TimeOfDay time;

  const TransactionReminderConfig({
    required this.enabled,
    required this.daysBefore,
    required this.time,
  });

  TransactionReminderConfig copyWith({
    bool? enabled,
    int? daysBefore,
    TimeOfDay? time,
  }) =>
      TransactionReminderConfig(
        enabled: enabled ?? this.enabled,
        daysBefore: daysBefore ?? this.daysBefore,
        time: time ?? this.time,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'daysBefore': daysBefore,
        'hour': time.hour,
        'minute': time.minute,
      };

  factory TransactionReminderConfig.fromJson(Map<String, dynamic> j) =>
      TransactionReminderConfig(
        enabled: j['enabled'] as bool? ?? false,
        daysBefore: j['daysBefore'] as int? ?? 0,
        time: TimeOfDay(
          hour: j['hour'] as int? ?? 9,
          minute: j['minute'] as int? ?? 0,
        ),
      );

  static TransactionReminderConfig get defaultConfig =>
      const TransactionReminderConfig(
        enabled: false,
        daysBefore: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      );
}

// Map: transactionId → config
class TransactionRemindersNotifier
    extends AsyncNotifier<Map<String, TransactionReminderConfig>> {
  @override
  Future<Map<String, TransactionReminderConfig>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTransactionReminders);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(
          k,
          TransactionReminderConfig.fromJson(v as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  TransactionReminderConfig configFor(String transactionId) {
    return state.valueOrNull?[transactionId] ??
        TransactionReminderConfig.defaultConfig;
  }

  Future<void> _save(Map<String, TransactionReminderConfig> configs) async {
    state = AsyncData(configs);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kTransactionReminders,
      jsonEncode(configs.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  Future<void> setConfig({
    required Transaction transaction,
    required TransactionReminderConfig config,
  }) async {
    final current = Map<String, TransactionReminderConfig>.from(
      state.valueOrNull ?? {},
    );
    current[transaction.id] = config;
    await _save(current);

    if (config.enabled) {
      await ReminderService.instance.scheduleTransactionReminder(
        transaction: transaction,
        daysBefore: config.daysBefore,
        hour: config.time.hour,
        minute: config.time.minute,
      );
    } else {
      await ReminderService.instance
          .cancelTransactionReminder(transaction.id);
    }
  }

  Future<void> setEnabled(Transaction transaction, bool value) async {
    final current = configFor(transaction.id);
    await setConfig(
      transaction: transaction,
      config: current.copyWith(enabled: value),
    );
  }

  Future<void> setDaysBefore(Transaction transaction, int days) async {
    final current = configFor(transaction.id);
    await setConfig(
      transaction: transaction,
      config: current.copyWith(daysBefore: days),
    );
  }

  Future<void> setTime(Transaction transaction, TimeOfDay time) async {
    final current = configFor(transaction.id);
    await setConfig(
      transaction: transaction,
      config: current.copyWith(time: time),
    );
  }
}

final transactionRemindersProvider = AsyncNotifierProvider<
    TransactionRemindersNotifier, Map<String, TransactionReminderConfig>>(
  TransactionRemindersNotifier.new,
);

// ── Convenience provider: recurring transactions with their reminder configs ──

class RecurringReminderEntry {
  final Transaction transaction;
  final TransactionReminderConfig config;
  const RecurringReminderEntry(this.transaction, this.config);
}

final recurringReminderEntriesProvider =
    Provider<List<RecurringReminderEntry>>((ref) {
  final txs = ref.watch(recurringTransactionsProvider);
  final configs = ref.watch(transactionRemindersProvider).valueOrNull ?? {};
  return txs
      .map((t) => RecurringReminderEntry(
            t,
            configs[t.id] ?? TransactionReminderConfig.defaultConfig,
          ))
      .toList();
});
