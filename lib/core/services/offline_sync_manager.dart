import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'offline_sync_queue_service.dart';
import 'app_logger.dart';

class OfflineSyncManager {
  final OfflineSyncQueueService _queueService;
  final Dio _dio;

  bool _isSyncing = false;

  OfflineSyncManager(this._queueService, this._dio);

  bool get isSyncing => _isSyncing;
  int get pendingCount => _queueService.getQueue().length;

  Future<void> syncPendingQueue({VoidCallback? onSyncComplete}) async {
    if (_isSyncing) return;
    final queue = _queueService.getQueue();
    if (queue.isEmpty) return;

    _isSyncing = true;
    AppLogger.instance
        .i('Starting offline sync for ${queue.length} items', tag: 'OfflineSync');

    try {
      for (final action in List<PendingSyncAction>.from(queue)) {
        try {
          switch (action.method) {
            case SyncHttpMethod.post:
              await _dio.post(action.endpoint, data: action.body);
              break;
            case SyncHttpMethod.put:
              await _dio.put(action.endpoint, data: action.body);
              break;
            case SyncHttpMethod.delete:
              await _dio.delete(action.endpoint, data: action.body);
              break;
          }
          await _queueService.remove(action.id);
          AppLogger.instance.i(
              'Synced item ${action.id} to ${action.endpoint}',
              tag: 'OfflineSync');
        } catch (e) {
          AppLogger.instance
              .e('Failed to sync item ${action.id}: $e', tag: 'OfflineSync');
          if (e is DioException &&
              (e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.connectionError)) {
            break;
          }
          // Remove bad request to prevent blocking the queue
          await _queueService.remove(action.id);
        }
      }
    } finally {
      _isSyncing = false;
      if (onSyncComplete != null) onSyncComplete();
    }
  }
}
