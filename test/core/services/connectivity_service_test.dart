import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitpay/core/services/connectivity_service.dart';

void main() {
  group('ConnectivityService Helper Tests', () {
    final service = ConnectivityService.instance;

    test('isOffline returns true when result contains ConnectivityResult.none', () {
      expect(service.isOffline([ConnectivityResult.none]), isTrue);
    });

    test('isOffline returns true when result is empty', () {
      expect(service.isOffline([]), isTrue);
    });

    test('isOffline returns false when wifi is present', () {
      expect(service.isOffline([ConnectivityResult.wifi]), isFalse);
    });

    test('isOffline returns false when mobile is present', () {
      expect(service.isOffline([ConnectivityResult.mobile]), isFalse);
    });

    test('isOffline returns false when ethernet is present', () {
      expect(service.isOffline([ConnectivityResult.ethernet]), isFalse);
    });

    test('isOffline returns false when vpn is present', () {
      expect(service.isOffline([ConnectivityResult.vpn]), isFalse);
    });

    test('getConnectionLabel formats wifi correctly', () {
      expect(service.getConnectionLabel([ConnectivityResult.wifi]), equals('Wi-Fi'));
    });

    test('getConnectionLabel formats cellular correctly', () {
      expect(service.getConnectionLabel([ConnectivityResult.mobile]), equals('Cellular Data'));
    });

    test('getConnectionLabel formats ethernet correctly', () {
      expect(service.getConnectionLabel([ConnectivityResult.ethernet]), equals('Ethernet'));
    });

    test('getConnectionLabel formats VPN correctly', () {
      expect(service.getConnectionLabel([ConnectivityResult.vpn]), equals('VPN'));
    });

    test('getConnectionLabel formats offline correctly', () {
      expect(service.getConnectionLabel([ConnectivityResult.none]), equals('Offline'));
    });
  });
}
