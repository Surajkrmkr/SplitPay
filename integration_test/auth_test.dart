import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth flow', () {
    testWidgets('unauthenticated boot shows login screen', (tester) async {
      await pumpTestApp(tester, authenticated: false);

      expect(find.text('Welcome to SplitPay'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('tapping Google sign-in navigates to home', (tester) async {
      await pumpTestApp(tester, authenticated: false, onboardingDone: true);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      // FakeAuthNotifier.signInWithGoogle() sets authenticated state → router
      // redirects from /login to /home.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();
      await pumpFrames(tester);

      // Login screen is gone once authenticated.
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('authenticated boot goes directly to home', (tester) async {
      await pumpTestApp(tester, authenticated: true, onboardingDone: true);

      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('sign-out from settings returns to login', (tester) async {
      await pumpTestApp(tester, authenticated: true, onboardingDone: true);

      // Navigate to the Settings / Profile tab (index 3) via person icon.
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await pumpFrames(tester);

      // Scroll so the Sign Out tile is visible.
      await tester.ensureVisible(find.text('Sign out of your account'));
      await tester.tap(find.text('Sign out of your account'));
      await tester.pump();

      // Confirm in the AlertDialog.
      await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });
}
