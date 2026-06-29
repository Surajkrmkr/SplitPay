import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitpay/data/models/transaction_model.dart';
import 'package:uuid/uuid.dart';

import 'helpers/test_app.dart';

Transaction _foodExpense(double amount) {
  final now = DateTime.now();
  return Transaction(
    id: const Uuid().v4(),
    amount: amount,
    type: TransactionType.expense,
    category: Category.food,
    date: now,
    createdAt: now,
    syncStatus: SyncStatus.synced,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Budget flow', () {
    testWidgets('create a new budget and verify it appears in the list',
        (tester) async {
      await pumpTestApp(tester, authenticated: true);

      // Navigate to Budget tab (index 2).
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await pumpFrames(tester);

      // Tap the 'New' add-budget button in the header.
      await tester.tap(find.text('New'));
      await tester.pump();
      await pumpFrames(tester);

      // Verify the sheet is open.
      expect(find.text('New Budget'), findsOneWidget);

      // Fill in the budget name.
      await tester.enterText(find.byType(TextField).first, 'Groceries');
      await tester.pump();

      // Fill in the budget amount (second text field).
      await tester.enterText(find.byType(TextField).at(1), '5000');
      await tester.pump();

      // Save.
      await tester.tap(find.text('Create Budget'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await pumpFrames(tester);

      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets('tapping a budget card opens the detail screen', (tester) async {
      await pumpTestApp(tester, authenticated: true);

      // Navigate to Budget tab and create one first.
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await pumpFrames(tester);
      await tester.tap(find.text('New'));
      await pumpFrames(tester);
      await tester.enterText(find.byType(TextField).first, 'Transport');
      await tester.enterText(find.byType(TextField).at(1), '2000');
      await tester.tap(find.text('Create Budget'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await pumpFrames(tester);

      // Tap the card.
      await tester.tap(find.text('Transport'));
      await pumpFrames(tester);

      // Budget detail screen should be visible.
      expect(find.text('Transport'), findsWidgets);
    });

    testWidgets('budget spent amount updates when matching transactions exist',
        (tester) async {
      final txs = [
        _foodExpense(300.0),
        _foodExpense(200.0),
      ];
      await pumpTestApp(tester, authenticated: true, seedTransactions: txs);

      // Navigate to Budget and create a Food budget.
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await pumpFrames(tester);
      await tester.tap(find.text('New'));
      await pumpFrames(tester);
      await tester.enterText(find.byType(TextField).first, 'Food Budget');
      await tester.enterText(find.byType(TextField).at(1), '1000');

      // Select 'Food' category in the budget category picker.
      await tester.tap(find.text('Food').last);
      await tester.pump();

      await tester.tap(find.text('Create Budget'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await pumpFrames(tester);

      // Open the detail screen.
      await tester.tap(find.text('Food Budget'));
      await pumpFrames(tester);

      // Some amount > 0 should be shown as spent.
      expect(find.textContaining('500'), findsWidgets);
    });
  });
}
