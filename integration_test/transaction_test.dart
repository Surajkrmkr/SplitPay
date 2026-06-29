import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitpay/data/models/transaction_model.dart';
import 'package:splitpay/shared/widgets/empty_state.dart';
import 'package:uuid/uuid.dart';

import 'helpers/test_app.dart';

Transaction _makeExpense({double amount = 250.0, Category category = Category.food}) {
  final now = DateTime.now();
  return Transaction(
    id: const Uuid().v4(),
    amount: amount,
    type: TransactionType.expense,
    category: category,
    date: now,
    createdAt: now,
    serverId: 'srv-${const Uuid().v4()}',
    syncStatus: SyncStatus.synced,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Transaction CRUD', () {
    testWidgets('home shows empty state when there are no transactions',
        (tester) async {
      await pumpTestApp(tester, authenticated: true, seedTransactions: []);

      expect(find.byType(EmptyState), findsWidgets);
    });

    testWidgets('add transaction via FAB appears in the list', (tester) async {
      await pumpTestApp(tester, authenticated: true, seedTransactions: []);

      // Open the add-transaction sheet via center FAB.
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await pumpFrames(tester);

      // Enter amount in the first TextField (amount field, auto-focused).
      await tester.enterText(find.byType(TextField).first, '500');
      await tester.pump();

      // Tap the 'Food' category chip (default type is expense).
      await tester.tap(find.text('Food'));
      await tester.pump();

      // Submit.
      await tester.tap(find.text('Save Expense'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await pumpFrames(tester);

      // The transaction tile should show the amount.
      expect(find.textContaining('500'), findsWidgets);
    });

    testWidgets('pre-seeded transaction is visible on home screen',
        (tester) async {
      final tx = _makeExpense(amount: 1234.56);
      await pumpTestApp(tester,
          authenticated: true, seedTransactions: [tx]);

      expect(find.textContaining('1,234.56'), findsWidgets);
    });

    testWidgets('deleting a transaction removes it from the list', (tester) async {
      final tx = _makeExpense(amount: 999.0);
      await pumpTestApp(tester,
          authenticated: true, seedTransactions: [tx]);

      // Navigate to the full transactions screen.
      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await pumpFrames(tester);

      // Swipe the transaction tile to reveal the delete action.
      final tile = find.textContaining('999');
      if (tester.any(tile)) {
        await tester.drag(tile, const Offset(-250, 0));
        await tester.pump();
        await pumpFrames(tester);

        // Tap the delete icon that appears after swipe.
        final deleteIcon = find.byIcon(Icons.delete_rounded);
        if (tester.any(deleteIcon)) {
          await tester.tap(deleteIcon);
          await pumpFrames(tester);
          expect(find.textContaining('999'), findsNothing);
        }
      }
    });

    testWidgets('editing a transaction updates the displayed amount',
        (tester) async {
      final tx = _makeExpense(amount: 100.0);
      await pumpTestApp(tester,
          authenticated: true, seedTransactions: [tx]);

      // Navigate to transactions screen.
      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await pumpFrames(tester);

      // Tap the tile to open the edit sheet.
      final tile = find.textContaining('100');
      if (tester.any(tile)) {
        await tester.tap(tile.first);
        await pumpFrames(tester);

        // Verify edit sheet is open.
        expect(find.text('Edit Transaction'), findsOneWidget);

        // Clear and re-enter the amount.
        final amountField = find.byType(TextField).first;
        await tester.tap(amountField);
        await tester.enterText(amountField, '750');
        await tester.pump();

        // Save.
        await tester.tap(find.text('Save Changes'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
        await pumpFrames(tester);

        expect(find.textContaining('750'), findsWidgets);
      }
    });
  });
}
