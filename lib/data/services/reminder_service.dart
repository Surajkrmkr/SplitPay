import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/services/app_logger.dart';
import '../models/transaction_model.dart';
import 'notification_service.dart';

// ── Stable notification IDs ───────────────────────────────────────────────────
// 1000 = daily reminder
// 2000–9999 = per-transaction reminders (deterministic hash)

const _kDailyReminderId = 1000;

const _channelId = 'dimeflow_reminders';
const _channelName = 'Reminders';
const _channelDesc = 'Daily expense and payment reminders';
const _tag = 'ReminderService';

int _txNotificationId(String transactionId) =>
    (transactionId.hashCode.abs() % 8000) + 2000;

class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  // Reuse the plugin that NotificationService already initialised with its
  // tap-callback. Creating a second instance and calling initialize() again
  // would silently wipe that callback, breaking FCM notification taps.
  FlutterLocalNotificationsPlugin get _plugin =>
      NotificationService.instance.localNotifications;

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
    final log = AppLogger.instance;
    log.i('init() started', tag: _tag);

    // 1. Load all IANA timezone data.
    tz_data.initializeTimeZones();
    log.i('Timezone DB loaded', tag: _tag);

    // 2. Set tz.local to the device's actual timezone.
    try {
      const channel = MethodChannel('com.splitpay.expensetracker/timezone');
      final String tzId =
          await channel.invokeMethod<String>('getLocalTimezone') ?? 'UTC';
      tz.setLocalLocation(tz.getLocation(tzId));
      log.i('Local timezone set → $tzId (tz.local=${tz.local.name})',
          tag: _tag);
    } catch (e) {
      log.e('Failed to get device timezone, falling back to UTC: $e',
          tag: _tag);
    }

    // 3. Create the reminders Android notification channel.
    //    Do NOT call _plugin.initialize() — NotificationService already did.
    try {
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
      log.i('Android channel "$_channelId" created/verified', tag: _tag);
    } catch (e) {
      log.e('Failed to create Android channel: $e', tag: _tag);
    }

    log.i('init() complete — tz.local=${tz.local.name}', tag: _tag);
  }

  // ── Generic scheduler ────────────────────────────────────────────────────

  Future<void> scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final log = AppLogger.instance;
    final now = tz.TZDateTime.now(tz.local);
    final diffMin = scheduledDate.difference(now).inMinutes;
    final whenStr = diffMin >= 0
        ? 'in ${diffMin}m'
        : 'PAST by ${diffMin.abs()}m — fires immediately';
    log.i(
      'Scheduling id=$notificationId\n'
      '  title="$title"\n'
      '  scheduledDate=$scheduledDate  ($whenStr, TZ=${tz.local.name})\n'
      '  repeat=${matchDateTimeComponents?.name ?? 'none'}',
      tag: _tag,
    );

    // Try exact alarm first (fires at the precise time).
    // Falls back to inexact if the SCHEDULE_EXACT_ALARM permission is not
    // granted (Android 13+ requires the user to approve in Settings).
    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
      log.i('zonedSchedule(EXACT) succeeded for id=$notificationId',
          tag: _tag);
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        log.w(
          'Exact alarms not permitted — falling back to inexact '
          '(up to 15 min delay). Grant "Alarms & reminders" permission in '
          'Settings → Special app access to enable precise timing.',
          tag: _tag,
        );
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
        log.i('zonedSchedule(INEXACT fallback) succeeded for id=$notificationId',
            tag: _tag);
      } else {
        log.e('zonedSchedule() FAILED for id=$notificationId: $e',
            tag: _tag, extra: e.stacktrace);
        rethrow;
      }
    } catch (e, st) {
      log.e('zonedSchedule() FAILED for id=$notificationId: $e',
          tag: _tag, extra: st.toString());
      rethrow;
    }

    await _logPendingNotifications();
  }

  Future<void> cancelReminder(int notificationId) async {
    AppLogger.instance.i('Cancelling id=$notificationId', tag: _tag);
    await _plugin.cancel(notificationId);
    AppLogger.instance.i('Cancelled id=$notificationId', tag: _tag);
    await _logPendingNotifications();
  }

  // ── Daily expense reminder ────────────────────────────────────────────────

  Future<void> scheduleDailyReminder(int hour, int minute) async {
    AppLogger.instance.i(
      'scheduleDailyReminder(hour=$hour, minute=$minute)',
      tag: _tag,
    );
    final next = _nextInstanceOf(hour, minute);
    final now = tz.TZDateTime.now(tz.local);
    final diffMin = next.difference(now).inMinutes;
    final whenStr = diffMin >= 0
        ? 'in ${diffMin}m (future)'
        : 'PAST by ${diffMin.abs()}m — fires immediately, then repeats daily';
    AppLogger.instance.i('Next fire time: $next  ($whenStr)', tag: _tag);
    await scheduleReminder(
      notificationId: _kDailyReminderId,
      title: '💸 Time to log your expenses',
      body: "Keep your records up to date — add today's transactions.",
      scheduledDate: next,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() => cancelReminder(_kDailyReminderId);

  // ── Per-transaction recurring reminders ──────────────────────────────────

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
    const title = '🔁 Recurring payment reminder';
    final body = daysBefore == 0
        ? '$label is due today.'
        : '$label is due in $daysBefore ${daysBefore == 1 ? 'day' : 'days'}.';

    AppLogger.instance.i(
      'scheduleTransactionReminder txId=${transaction.id} '
      'recurrence=${transaction.recurrence.name} '
      'daysBefore=$daysBefore $hour:${minute.toString().padLeft(2, '0')}',
      tag: _tag,
    );

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
        final targetDay =
            _shiftWeekday(transaction.date.weekday, -daysBefore);
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
        AppLogger.instance
            .w('scheduleTransactionReminder called on non-recurring tx',
                tag: _tag);
    }
  }

  Future<void> cancelTransactionReminder(String transactionId) async {
    await cancelReminder(_txNotificationId(transactionId));
  }

  // ── Pending notification dump (debug) ───────────────────────────────────

  Future<void> _logPendingNotifications() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      if (pending.isEmpty) {
        AppLogger.instance
            .w('Pending notifications: NONE', tag: _tag);
      } else {
        final lines = pending
            .map((n) => '  id=${n.id} title="${n.title}"')
            .join('\n');
        AppLogger.instance.i(
          'Pending notifications (${pending.length}):\n$lines',
          tag: _tag,
        );
      }
    } catch (e) {
      AppLogger.instance.e('Could not fetch pending list: $e', tag: _tag);
    }
  }

  // ── Date helpers ─────────────────────────────────────────────────────────

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    final todayAt =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // If today's time has already passed, return it anyway — Android's
    // AlarmManager fires a past trigger immediately and then repeats daily at
    // this hour:minute. Do NOT add a day; that would silently delay the first
    // notification until tomorrow.
    return todayAt;
  }

  tz.TZDateTime _nextWeekdayInstance(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
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

  int _shiftWeekday(int weekday, int delta) =>
      ((weekday - 1 + delta) % 7 + 7) % 7 + 1;
}
