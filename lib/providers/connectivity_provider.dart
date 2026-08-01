import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/offline_sync_manager.dart';
import '../core/services/offline_sync_queue_service.dart';
import 'group_provider.dart';
import 'transaction_provider.dart';

/// Provider for the singleton instance of ConnectivityService
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

/// Stream provider for real-time connectivity result list updates
final connectivityStatusProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  // Yield initial connectivity state
  final initial = await service.checkConnectivity();
  yield initial;

  // Listen to connectivity stream
  await for (final status in service.onConnectivityChanged) {
    yield status;
  }
});

/// Returns true if the device is currently offline
final isOfflineProvider = Provider<bool>((ref) {
  final asyncValue = ref.watch(connectivityStatusProvider);
  return asyncValue.when(
    data: (results) => ref.watch(connectivityServiceProvider).isOffline(results),
    loading: () => false, // Assume online while loading initial state
    error: (_, __) => false,
  );
});

/// Returns human-readable connection status string (e.g. "Wi-Fi", "Cellular Data", "Offline")
final connectionTypeLabelProvider = Provider<String>((ref) {
  final asyncValue = ref.watch(connectivityStatusProvider);
  return asyncValue.when(
    data: (results) => ref.watch(connectivityServiceProvider).getConnectionLabel(results),
    loading: () => 'Checking...',
    error: (_, __) => 'Unknown',
  );
});

/// Offline sync queue service provider
final offlineSyncQueueServiceProvider = Provider<OfflineSyncQueueService>((ref) {
  return OfflineSyncQueueService();
});

/// Offline sync manager provider
final offlineSyncManagerProvider = Provider<OfflineSyncManager>((ref) {
  final manager = OfflineSyncManager(
    ref.watch(offlineSyncQueueServiceProvider),
    ref.watch(dioProvider),
  );

  // Auto-sync pending actions when device re-establishes connectivity
  ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityStatusProvider, (previous, next) {
    next.whenData((results) {
      final isOffline = ref.read(connectivityServiceProvider).isOffline(results);
      if (!isOffline) {
        manager.syncPendingQueue(onSyncComplete: () {
          ref.invalidate(groupsProvider);
          ref.invalidate(transactionProvider);
        });
      }
    });
  });

  return manager;
});
