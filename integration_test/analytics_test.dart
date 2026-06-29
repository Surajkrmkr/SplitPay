import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitpay/data/models/transaction_model.dart';
import 'package:splitpay/features/analytics/analytics_screen.dart';
import 'package:uuid/uuid.dart';

import 'helpers/test_app.dart';

List<Transaction> _sampleTransactions() {
  final now = DateTime.now();
  final categories = [
    Category.food,
    Category.shopping,
    Category.bills,
    Category.health,
    Category.entertainment,
  ];
  return List.generate(5, (i) {
    return Transaction(
      id: const Uuid().v4(),
      amount: (i + 1) * 150.0,
      type: TransactionType.expense,
      category: categories[i],
      date: now.subtract(Duration(days: i)),
      createdAt: now,
      syncStatus: SyncStatus.synced,
    );
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Analytics screen', () {
    testWidgets('opens without crashing when transactions exist', (tester) async {
      await pumpTestApp(
        tester,
        authenticated: true,
        seedTransactions: _sampleTransactions(),
      );

      // Tap 'Full report' from the home analytics mini widget.
      await tester.tap(find.text('Full report'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await pumpFrames(tester);

      expect(find.byType(AnalyticsScreen), findsOneWidget);
    });

    testWidgets('opens without crashing when there are no transactions',
        (tester) async {
      await pumpTestApp(tester, authenticated: true, seedTransactions: []);

      await tester.tap(find.text('Full report'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await pumpFrames(tester);

      // Empty analytics shows a 'No data yet' placeholder.
      expect(find.text('No data yet'), findsOneWidget);
    });
  });
}
