import 'package:connectivity_plus/connectivity_plus.dart';

import 'app_logger.dart';

/// Service wrapping connectivity checking and status observation
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  /// Check the current connectivity status
  Future<List<ConnectivityResult>> checkConnectivity() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      AppLogger.instance.e('Error checking connectivity: $e', tag: 'Connectivity');
      return [ConnectivityResult.none];
    }
  }

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Helper to determine if a list of ConnectivityResult indicates offline status
  bool isOffline(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    if (results.contains(ConnectivityResult.none)) return true;
    final hasConnection = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn ||
        r == ConnectivityResult.other);
    return !hasConnection;
  }

  /// Get human-readable connection label
  String getConnectionLabel(List<ConnectivityResult> results) {
    if (isOffline(results)) {
      return 'Offline';
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return 'Wi-Fi';
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return 'Cellular Data';
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    }
    if (results.contains(ConnectivityResult.vpn)) {
      return 'VPN';
    }
    return 'Connected';
  }
}
