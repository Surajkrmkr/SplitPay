import 'package:flutter_test/flutter_test.dart';
import 'package:splitpay/features/home/widgets/greeting_header.dart';

void main() {
  group('greetingForLocalTime', () {
    test('uses evening greeting overnight', () {
      expect(greetingForLocalTime(DateTime(2026, 1, 1, 0)), 'Good Evening');
      expect(greetingForLocalTime(DateTime(2026, 1, 1, 4, 59)), 'Good Evening');
    });

    test('uses morning greeting from 5 AM until noon', () {
      expect(greetingForLocalTime(DateTime(2026, 1, 1, 5)), 'Good Morning');
      expect(
          greetingForLocalTime(DateTime(2026, 1, 1, 11, 59)), 'Good Morning');
    });

    test('uses afternoon greeting from noon until 5 PM', () {
      expect(greetingForLocalTime(DateTime(2026, 1, 1, 12)), 'Good Afternoon');
      expect(
        greetingForLocalTime(DateTime(2026, 1, 1, 16, 59)),
        'Good Afternoon',
      );
    });

    test('uses evening greeting from 5 PM onward', () {
      expect(greetingForLocalTime(DateTime(2026, 1, 1, 17)), 'Good Evening');
      expect(
        greetingForLocalTime(DateTime(2026, 1, 1, 23, 59)),
        'Good Evening',
      );
    });
  });
}
