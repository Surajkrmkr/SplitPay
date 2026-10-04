import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitpay/core/storage/preferences_service.dart';
import 'package:splitpay/core/utils/currency_formatter.dart';
import 'package:splitpay/data/models/group_model.dart';
import 'package:splitpay/features/home/widgets/balance_card.dart';
import 'package:splitpay/features/home/widgets/dashboard_cards_carousel.dart';
import 'package:splitpay/features/home/widgets/group_overview_card.dart';
import 'package:splitpay/providers/group_provider.dart';
import 'package:splitpay/providers/transaction_provider.dart';

class _EmptyGroupsNotifier extends GroupsNotifier {
  @override
  Future<List<GroupModel>> build() async => [];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'currency': '₹'});
    await PreferencesService.init();
  });

  Future<void> pumpCard(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          totalIncomeProvider.overrideWithValue(10633),
          totalExpenseProvider.overrideWithValue(4625),
          balanceProvider.overrideWithValue(6008),
          previousMonthExpenseProvider.overrideWithValue(15000),
          groupsProvider.overrideWith(_EmptyGroupsNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: 390, height: 250, child: card),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('cards align their headers, amounts, dividers and footer labels',
      (tester) async {
    await pumpCard(tester, const BalanceCard());
    final header = tester.getTopLeft(find.text('Total Balance'));
    final amount = tester.getTopLeft(
      find.text(CurrencyFormatter.format(6008)),
    );
    final footer = tester.getTopLeft(find.text('Income')).dy;
    final divider = tester
        .getTopLeft(find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.constraints?.maxHeight == 0.5,
        ))
        .dy;
    final amountStyle = tester
        .widget<Text>(
          find.text(CurrencyFormatter.format(6008)),
        )
        .style;
    expect(tester.takeException(), isNull);

    await pumpCard(tester, const GroupOverviewCard());
    expect(tester.getTopLeft(find.text('Group Overview')), header);
    expect(
      tester.getTopLeft(find.text(CurrencyFormatter.format(0)).first),
      amount,
    );
    expect(tester.getTopLeft(find.text('You owe')).dy, footer);
    expect(
      tester
          .getTopLeft(find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.constraints?.maxHeight == 0.5,
          ))
          .dy,
      divider,
    );
    final groupAmountStyle = tester
        .widget<Text>(
          find.text(CurrencyFormatter.format(0)).first,
        )
        .style;
    expect(groupAmountStyle?.fontSize, amountStyle?.fontSize);
    expect(groupAmountStyle?.letterSpacing, amountStyle?.letterSpacing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('balance displays the final amount without a digit tween',
      (tester) async {
    await pumpCard(tester, const BalanceCard());
    final amount = find.text(CurrencyFormatter.format(6008));
    expect(amount, findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(amount, findsOneWidget);
  });

  testWidgets('carousel reserves shadow space without clipping its pages',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          totalIncomeProvider.overrideWithValue(10633),
          totalExpenseProvider.overrideWithValue(4625),
          balanceProvider.overrideWithValue(6008),
          previousMonthExpenseProvider.overrideWithValue(15000),
          groupsProvider.overrideWith(_EmptyGroupsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 390, child: DashboardCardsCarousel()),
          ),
        ),
      ),
    );
    await tester.pump();
    final pageView = find.byType(PageView);
    expect(tester.widget<PageView>(pageView).clipBehavior, Clip.none);
    expect(tester.getSize(pageView).height, 282);
    expect(tester.getSize(find.byType(BalanceCard)).height, 250);
    final pageRect = tester.getRect(pageView);
    final cardRect = tester.getRect(find.byType(BalanceCard));
    expect(cardRect.top - pageRect.top, 8);
    expect(pageRect.bottom - cardRect.bottom, 24);
    expect(tester.takeException(), isNull);
    // Dispose the carousel's periodic auto-slide timer.
    await tester.pumpWidget(const SizedBox());
  });
}
