import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitpay/core/storage/preferences_service.dart';
import 'package:splitpay/data/models/group_model.dart';
import 'package:splitpay/features/groups/widgets/my_balance_summary.dart';
import 'package:splitpay/providers/group_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  for (final width in [320.0, 390.0]) {
    for (final brightness in Brightness.values) {
      for (final textScale in [1.0, 1.5]) {
        testWidgets(
          'Overview aligns at $width, $brightness, text scale $textScale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  groupsProvider.overrideWith(_EmptyGroupsNotifier.new),
                ],
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 800),
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: const Scaffold(body: MyBalanceSummary()),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final totalLabel = find.text('Total spent');
            final monthLabel = find.text('This month');
            expect(
              tester.getTopLeft(totalLabel).dy,
              tester.getTopLeft(monthLabel).dy,
            );
            expect(
              tester.getTopLeft(find.text('Net balance')).dy,
              greaterThan(tester.getBottomLeft(totalLabel).dy),
            );
            expect(find.text('Settled'), findsOneWidget);
            expect(tester.takeException(), isNull);

            await tester.tap(find.text('Your overview'));
            await tester.pumpAndSettle();
            expect(find.text("You're owed"), findsOneWidget);
            expect(find.text('You owe'), findsOneWidget);
            expect(tester.takeException(), isNull);

            await tester.tap(find.text('Your overview'));
            await tester.pumpAndSettle();
            expect(find.text('You owe'), findsNothing);
          },
        );
      }
    }
  }
}

class _EmptyGroupsNotifier extends GroupsNotifier {
  @override
  Future<List<GroupModel>> build() async => [];
}
