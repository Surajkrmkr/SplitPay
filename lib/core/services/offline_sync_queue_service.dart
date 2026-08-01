import 'dart:convert';

import '../storage/preferences_service.dart';
import 'app_logger.dart';

enum SyncHttpMethod { post, put, delete }

class PendingSyncAction {
  final String id;
  final String endpoint;
  final SyncHttpMethod method;
  final Map<String, dynamic> body;
  final DateTime createdAt;

  PendingSyncAction({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.body,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method.name,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingSyncAction.fromJson(Map<String, dynamic> json) =>
      PendingSyncAction(
        id: json['id'] as String,
        endpoint: json['endpoint'] as String,
        method: SyncHttpMethod.values.firstWhere(
          (m) => m.name == json['method'],
          orElse: () => SyncHttpMethod.post,
        ),
        body: Map<String, dynamic>.from(json['body'] as Map? ?? {}),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class OfflineSyncQueueService {
  static const _storageKey = 'offline_pending_sync_queue';

  List<PendingSyncAction> getQueue() {
    try {
      final rawList = PreferencesService.getStringList(_storageKey);
      if (rawList == null || rawList.isEmpty) return [];
      return rawList
          .map((item) =>
              PendingSyncAction.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.instance
          .e('Error loading offline sync queue: $e', tag: 'OfflineSync');
      return [];
    }
  }

  Future<void> enqueue(PendingSyncAction action) async {
    final queue = getQueue();
    queue.add(action);
    await _saveQueue(queue);
  }

  Future<void> remove(String actionId) async {
    final queue = getQueue();
    queue.removeWhere((a) => a.id == actionId);
    await _saveQueue(queue);
  }

  Future<void> clear() async {
    await PreferencesService.remove(_storageKey);
  }

  Future<void> _saveQueue(List<PendingSyncAction> queue) async {
    final rawList = queue.map((a) => jsonEncode(a.toJson())).toList();
    await PreferencesService.set(_storageKey, rawList);
  }
}
