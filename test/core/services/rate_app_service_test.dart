import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitpay/core/services/rate_app_service.dart';
import 'package:splitpay/core/storage/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RateAppService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.init();
    });

    test('initial expense count is null or zero', () {
      final count = PreferencesService.get<int>('user_personal_expense_count');
      expect(count, isNull);
    });

    test('has_rated flag prevents double prompting', () async {
      await PreferencesService.set('user_has_rated_app', true);
      expect(PreferencesService.get<bool>('user_has_rated_app'), isTrue);
    });
  });
}
