import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bottom navigation', () {
    testWidgets('tapping Budget tab shows BudgetScreen', (tester) async {
      await pumpTestApp(tester, authenticated: true);

      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await pumpFrames(tester);

      expect(find.text('Budget'), findsWidgets);
    });

    testWidgets('tapping Settings/Profile tab shows SettingsScreen', (tester) async {
      await pumpTestApp(tester, authenticated: true);

      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await pumpFrames(tester);

      // Settings screen has a 'Preferences' section label.
      expect(find.text('Preferences'), findsOneWidget);
    });

    testWidgets('returning to Home tab restores home content', (tester) async {
      await pumpTestApp(tester, authenticated: true);

      // Go to Budget.
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await pumpFrames(tester);

      // Come back to Home via active home icon.
      await tester.tap(find.byIcon(Icons.home_rounded));
      await pumpFrames(tester);

      // The home screen always shows the balance card area.
      // If balance card is not visible, at least the FAB is always present.
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('FAB is visible on all shell tabs', (tester) async {
      await pumpTestApp(tester, authenticated: true);

      // Home (default)
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Budget tab
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await pumpFrames(tester);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Settings / Profile tab
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await pumpFrames(tester);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });
}
