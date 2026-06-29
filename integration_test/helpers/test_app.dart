import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitpay/app.dart';
import 'package:splitpay/core/network/api_client.dart';
import 'package:splitpay/core/storage/preferences_service.dart';
import 'package:splitpay/data/models/transaction_model.dart';
import 'package:splitpay/data/repositories/transaction_repository.dart';
import 'package:splitpay/providers/auth_provider.dart';

import 'fake_auth_notifier.dart';
import 'fake_transaction_repo.dart';

/// A fast-failing Dio for tests: points at a closed port so every request
/// rejects in ~100 ms with a proper [DioException] instead of hanging.
Dio _testDio() => Dio(
      BaseOptions(
        baseUrl: 'http://localhost:19999',
        connectTimeout: const Duration(milliseconds: 200),
        receiveTimeout: const Duration(milliseconds: 200),
      ),
    );

/// Bootstraps the whole app with all external dependencies replaced by fakes,
/// then pumps the widget tree and advances time past the splash screen delay.
///
/// Call this at the start of every integration test instead of [pumpWidget].
Future<void> pumpTestApp(
  WidgetTester tester, {
  bool authenticated = false,
  bool onboardingDone = true,
  List<Transaction> seedTransactions = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    if (onboardingDone) 'onboarding_completed': true,
  });
  await PreferencesService.init();

  final fakeRepo = FakeTransactionRepository(seed: seedTransactions);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Auth: bypass Firebase + token storage entirely
        authProvider.overrideWith(
          () => FakeAuthNotifier(initiallyAuthenticated: authenticated),
        ),
        // Transactions: in-memory store
        transactionRepositoryProvider.overrideWithValue(fakeRepo),
        // Dio: fast-failing stub so Group / Category API calls don't hang
        dioProvider.overrideWithValue(_testDio()),
      ],
      child: const SplitPayApp(),
    ),
  );

  // The SplashScreen navigates after a 400 ms Future.delayed triggered by
  // the authProvider listener. Wait past that then pump one frame.
  await Future<void>.delayed(const Duration(milliseconds: 600));
  await tester.pump();

  // Settle non-repeating transitions (page transitions, hero animations).
  // Use a short timeout so repeating flutter_animate decorations don't block.
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } on FlutterError {
    // Repeating animations prevented full settle — that's acceptable.
    // The relevant widgets are already present in the tree.
  }
}

/// Pump a small number of frames to let one-shot animations finish without
/// blocking on repeating ones.  Use instead of [pumpAndSettle] when you know
/// the screen has looping animations.
Future<void> pumpFrames(WidgetTester tester,
    [Duration duration = const Duration(milliseconds: 400)]) async {
  final deadline = DateTime.now().add(duration);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
