import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../../data/models/transaction_model.dart';

class HomeWidgetService {
  static const String appGroupId = 'group.com.splitpay.expensetracker';
  static const String androidWidgetName = 'BalanceRecentWidgetProvider';

  static Future<void> updateWidgetData({
    required double balance,
    required double totalIncome,
    required double totalExpense,
    required String currency,
    required List<Transaction> recentTransactions,
  }) async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);

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

      // Also save full JSON list for advanced widgets
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
        androidName: androidWidgetName,
      );
    } catch (_) {
      // Ignore widget update errors if framework bindings unavailable
    }
  }
}
