import 'package:flutter_test/flutter_test.dart';
import 'package:splitpay/core/services/home_widget_launch_handler.dart';

void main() {
  group('homeWidgetRouteFor', () {
    test('keeps existing widget routes', () {
      expect(
        homeWidgetRouteFor(Uri.parse('dimeflow://widget/budget')),
        '/budget',
      );
    });

    test('routes personal expense shortcut', () {
      expect(
        homeWidgetRouteFor(
          Uri.parse('dimeflow://shortcut/add-expense?homeWidget=1'),
        ),
        '/shortcut/add-expense',
      );
    });

    test('routes group expense shortcut', () {
      expect(
        homeWidgetRouteFor(
          Uri.parse('dimeflow://shortcut/add-group-expense?homeWidget=1'),
        ),
        '/shortcut/add-group-expense',
      );
    });

    test('ignores unsupported launch URLs', () {
      expect(homeWidgetRouteFor(null), isNull);
      expect(homeWidgetRouteFor(Uri.parse('https://example.com')), isNull);
      expect(
          homeWidgetRouteFor(Uri.parse('dimeflow://shortcut/unknown')), isNull);
    });
  });
}
