import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitpay/providers/connectivity_provider.dart';
import 'package:splitpay/shared/widgets/network_status_banner.dart';

void main() {
  testWidgets('NetworkStatusBannerListener renders child widget', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityStatusProvider.overrideWith((ref) => Stream.value([ConnectivityResult.wifi])),
        ],
        child: const MaterialApp(
          home: NetworkStatusBannerListener(
            child: Scaffold(
              body: Text('Test Content'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Test Content'), findsOneWidget);
  });
}
