import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/transaction_model.dart';

// ── Stable notification IDs ───────────────────────────────────────────────────
// 1000 = daily reminder
// 2000–9999 = per-transaction reminders (deterministic hash)

const _kDailyReminderId = 1000;

const _channelId = 'dimeflow_reminders';
const _channelName = 'Reminders';
const _channelDesc = 'Daily expense and payment reminders';

int _txNotificationId(String transactionId) =>
    (transactionId.hashCode.abs() % 8000) + 2000;

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.high,
    priority: Priority.high,
    icon: '@drawable/ic_stat_notify',
    color: Color(0xFF00D09C),
  );

  static const _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const _details = NotificationDetails(
    android: _androidDetails,
    iOS: _iosDetails,
  );

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@drawable/ic_stat_notify');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );
  }

  // ── Generic scheduler (extensible entry point) ────────────────────────────

  Future<void> scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      _details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  Future<void> cancelReminder(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  // ── Daily expense reminder ────────────────────────────────────────────────

  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await scheduleReminder(
      notificationId: _kDailyReminderId,
      title: '💸 Time to log your expenses',
      body: 'Keep your records up to date — add today\'s transactions.',
      scheduledDate: _nextInstanceOf(hour, minute),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() => cancelReminder(_kDailyReminderId);

  // ── Per-transaction recurring reminders ───────────────────────────────────

  Future<void> scheduleTransactionReminder({
    required Transaction transaction,
    required int daysBefore,
    required int hour,
    required int minute,
  }) async {
    final id = _txNotificationId(transaction.id);
    final label = transaction.note?.isNotEmpty == true
        ? transaction.note!
        : transaction.category.label;
    final title = '🔁 Recurring payment reminder';
    final body = daysBefore == 0
        ? '$label is due today.'
        : '$label is due in $daysBefore ${daysBefore == 1 ? 'day' : 'days'}.';

    switch (transaction.recurrence) {
      case RecurrenceType.daily:
        await scheduleReminder(
          notificationId: id,
          title: title,
          body: body,
          scheduledDate: _nextInstanceOf(hour, minute),
          matchDateTimeComponents: DateTimeComponents.time,
        );
      case RecurrenceType.weekly:
        final targetDay = _shiftWeekday(transaction.date.weekday, -daysBefore);
        await scheduleReminder(
          notificationId: id,
          title: title,
          body: body,
          scheduledDate: _nextWeekdayInstance(targetDay, hour, minute),
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      case RecurrenceType.monthly:
        final targetDay =
            (transaction.date.day - daysBefore).clamp(1, 28);
        await scheduleReminder(
          notificationId: id,
          title: title,
          body: body,
          scheduledDate: _nextMonthlyInstance(targetDay, hour, minute),
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
      case RecurrenceType.yearly:
        await scheduleReminder(
          notificationId: id,
          title: title,
          body: body,
          scheduledDate: _nextYearlyInstance(
              transaction.date, daysBefore, hour, minute),
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      case RecurrenceType.none:
        break;
    }
  }

  Future<void> cancelTransactionReminder(String transactionId) async {
    await cancelReminder(_txNotificationId(transactionId));
  }

  // ── Date helpers ──────────────────────────────────────────────────────────

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  tz.TZDateTime _nextWeekdayInstance(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (t.weekday != weekday || t.isBefore(now)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  tz.TZDateTime _nextMonthlyInstance(int day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, day, hour, minute);
    if (t.isBefore(now)) {
      final nm = now.month == 12 ? 1 : now.month + 1;
      final ny = now.month == 12 ? now.year + 1 : now.year;
      t = tz.TZDateTime(tz.local, ny, nm, day, hour, minute);
    }
    return t;
  }

  tz.TZDateTime _nextYearlyInstance(
      DateTime original, int daysBefore, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    final target = original.subtract(Duration(days: daysBefore));
    var t = tz.TZDateTime(
        tz.local, now.year, target.month, target.day, hour, minute);
    if (t.isBefore(now)) {
      t = tz.TZDateTime(
          tz.local, now.year + 1, target.month, target.day, hour, minute);
    }
    return t;
  }

  // Shift a weekday (1=Mon … 7=Sun) by [delta] days, wrapping correctly.
  int _shiftWeekday(int weekday, int delta) =>
      ((weekday - 1 + delta) % 7 + 7) % 7 + 1;
}
