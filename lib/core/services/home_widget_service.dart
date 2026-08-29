import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../../data/models/transaction_model.dart';

/// Pushes app data into shared storage (App Group on iOS, SharedPreferences
/// on Android) and asks the OS to redraw the home-screen widgets.
///
/// Three widgets are supported on both platforms, sharing one data blob:
///  - Overall Budget   (arc gauge of spend vs. the active budget total)
///  - Recent Transactions (net-this-week + latest expenses)
///  - Insights         (5-bucket monthly spend bar chart)
class HomeWidgetService {
  static const String appGroupId = 'group.com.splitpay.expensetracker';

  // Android AppWidgetProvider class names.
  static const String androidOverallBudgetWidget = 'OverallBudgetWidgetProvider';
  static const String androidRecentTransactionsWidget =
      'RecentTransactionsWidgetProvider';
  static const String androidInsightsWidget = 'InsightsWidgetProvider';

  // iOS WidgetKit `kind` identifiers (must match the `kind:` passed to each
  // `Widget` in the DimeWidgets extension's WidgetBundle).
  static const String iosOverallBudgetWidget = 'OverallBudgetWidget';
  static const String iosRecentTransactionsWidget = 'RecentTransactionsWidget';
  static const String iosInsightsWidget = 'InsightsWidget';

  static Future<void> updateWidgetData({
    required double balance,
    required double totalIncome,
    required double totalExpense,
    required String currency,
    required List<Transaction> recentTransactions,
    // Overall Budget widget.
    required bool hasBudgetData,
    required String budgetPeriodLabel,
    required double budgetSpent,
    required double budgetLimit,
    // Insights widget — 5 buckets of ~7 days each, covering the current
    // calendar month (day 1-7, 8-14, 15-21, 22-28, 29-31).
    required List<double> monthBucketAmounts,
    // Recent Transactions widget.
    required double netThisWeek,
    // Arc gauge / bar chart fill color — the user's selected accent color
    // from Settings, replacing what used to be a hardcoded near-black.
    required Color accentColor,
  }) async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);

      // ── Legacy / shared balance fields ──────────────────────────────────
      await HomeWidget.saveWidgetData<String>(
        'balance',
        '$currency${balance.toStringAsFixed(2)}',
      );
      await HomeWidget.saveWidgetData<String>(
        'total_income',
        '+$currency${totalIncome.toStringAsFixed(2)}',
      );
      await HomeWidget.saveWidgetData<String>(
        'total_expense',
        '-$currency${totalExpense.toStringAsFixed(2)}',
      );
      await HomeWidget.saveWidgetData<String>('currency', currency);
      await HomeWidget.saveWidgetData<String>('accent_color', _hex(accentColor));

      // ── Overall Budget widget ────────────────────────────────────────────
      final budgetRemaining = (budgetLimit - budgetSpent).clamp(0.0, double.infinity);
      final budgetPercent = budgetLimit > 0
          ? ((budgetSpent / budgetLimit) * 100).clamp(0, 100).round()
          : 0;

      await HomeWidget.saveWidgetData<String>(
        'ob_has_data',
        hasBudgetData ? 'true' : 'false',
      );
      await HomeWidget.saveWidgetData<String>('ob_period_label', budgetPeriodLabel);
      await HomeWidget.saveWidgetData<String>('ob_percent', '$budgetPercent');
      await HomeWidget.saveWidgetData<String>(
          'ob_spent', _grouped(budgetSpent));
      await HomeWidget.saveWidgetData<String>(
          'ob_limit', _grouped(budgetLimit));
      await HomeWidget.saveWidgetData<String>(
          'ob_remaining', _grouped(budgetRemaining));

      // ── Insights widget ──────────────────────────────────────────────────
      final monthTotal =
          monthBucketAmounts.fold<double>(0, (sum, v) => sum + v);
      await HomeWidget.saveWidgetData<String>(
        'in_has_data',
        monthTotal > 0 ? 'true' : 'false',
      );
      await HomeWidget.saveWidgetData<String>(
          'in_month_total', monthTotal.toStringAsFixed(2));
      for (int i = 0; i < 5; i++) {
        final value = i < monthBucketAmounts.length ? monthBucketAmounts[i] : 0.0;
        await HomeWidget.saveWidgetData<String>(
            'in_bucket$i', value.toStringAsFixed(2));
      }

      // ── Recent Transactions widget ──────────────────────────────────────
      await HomeWidget.saveWidgetData<String>(
          'rt_net_week', netThisWeek.toStringAsFixed(2));
      await HomeWidget.saveWidgetData<String>(
        'rt_has_data',
        recentTransactions.isNotEmpty ? 'true' : 'false',
      );

      final recents = recentTransactions.take(3).toList();
      for (int i = 0; i < 3; i++) {
        final keyIndex = i + 1;
        if (i < recents.length) {
          final tx = recents[i];
          final note = (tx.note != null && tx.note!.trim().isNotEmpty)
              ? tx.note!.trim()
              : (tx.customCategoryId != null ? 'Custom' : tx.category.name);
          final prefix = tx.type == TransactionType.income ? '+' : '-';
          final amountStr = '$prefix$currency${tx.amount.toStringAsFixed(2)}';

          await HomeWidget.saveWidgetData<String>('tx${keyIndex}_note', note);
          await HomeWidget.saveWidgetData<String>('tx${keyIndex}_amount', amountStr);
          await HomeWidget.saveWidgetData<String>('tx${keyIndex}_type', tx.type.name);
        } else {
          await HomeWidget.saveWidgetData<String>('tx${keyIndex}_note', '');
          await HomeWidget.saveWidgetData<String>('tx${keyIndex}_amount', '');
          await HomeWidget.saveWidgetData<String>('tx${keyIndex}_type', '');
        }
      }

      // Also save full JSON list for advanced widgets.
      final jsonList = recents.map((tx) {
        final note = (tx.note != null && tx.note!.trim().isNotEmpty)
            ? tx.note!.trim()
            : (tx.customCategoryId != null ? 'Custom' : tx.category.name);
        return {
          'id': tx.id,
          'amount': '$currency${tx.amount.toStringAsFixed(2)}',
          'type': tx.type.name,
          'note': note,
          'date': tx.date.toIso8601String(),
        };
      }).toList();

      await HomeWidget.saveWidgetData<String>(
        'recent_transactions',
        jsonEncode(jsonList),
      );

      await HomeWidget.updateWidget(
        androidName: androidOverallBudgetWidget,
        iOSName: iosOverallBudgetWidget,
      );
      await HomeWidget.updateWidget(
        androidName: androidRecentTransactionsWidget,
        iOSName: iosRecentTransactionsWidget,
      );
      await HomeWidget.updateWidget(
        androidName: androidInsightsWidget,
        iOSName: iosInsightsWidget,
      );
    } catch (_) {
      // Ignore widget update errors if framework bindings unavailable.
    }
  }

  /// Formats [color] as an opaque `#RRGGBB` hex string for the native side to parse.
  static String _hex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  /// Formats [value] as a thousands-grouped integer string, e.g. `12,252`.
  static String _grouped(double value) {
    final rounded = value.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
    }
    return (rounded < 0 ? '-' : '') + buffer.toString();
  }
}
