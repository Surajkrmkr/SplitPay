import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';
import '../services/transaction_api_service.dart';

enum SyncState { idle, syncing, error, offline }

class SyncResult {
  final int pushed;
  final int pulled;
  final int failed;
  final DateTime syncedAt;
  final String? errorMessage;

  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.failed,
    required this.syncedAt,
    this.errorMessage,
  });
}

class SyncService {
  final TransactionApiService _api;

  // Debounce: avoid hammering the server when the user saves several
  // transactions in quick succession.
  Timer? _debounceTimer;
  static const _debounce = Duration(seconds: 3);

  // Back-off state for failed syncs.
  int _failCount = 0;
  static const _maxBackoffSeconds = 300;

  SyncService(this._api);

  /// Triggers a sync after a short debounce. Safe to call on every write.
  /// [onSyncSuccess] is called with the server timestamp when sync succeeds.
  void scheduleSync(
    void Function(SyncState) onStateChange, {
    void Function(DateTime)? onSyncSuccess,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () async {
      final result = await sync(onStateChange);
      if (result.errorMessage == null) {
        onSyncSuccess?.call(result.syncedAt);
      }
    });
  }

  /// Performs a full push→pull cycle. Returns a [SyncResult].
  Future<SyncResult> sync(void Function(SyncState) onStateChange) async {
    onStateChange(SyncState.syncing);

    try {
      final pushed = await _pushPending();
      final pulled = await _pullLatest();

      _failCount = 0;
      final result = SyncResult(
        pushed: pushed,
        pulled: pulled,
        failed: 0,
        syncedAt: DateTime.now(),
      );
      onStateChange(SyncState.idle);
      return result;
    } on SocketException catch (_) {
      onStateChange(SyncState.offline);
      return SyncResult(
        pushed: 0, pulled: 0, failed: 0,
        syncedAt: DateTime.now(),
        errorMessage: 'No internet connection',
      );
    } catch (e) {
      _failCount++;
      onStateChange(SyncState.error);
      return SyncResult(
        pushed: 0, pulled: 0, failed: 1,
        syncedAt: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }

  /// Backoff duration based on consecutive failure count (exponential, capped).
  Duration get retryBackoff {
    final seconds = (2 << _failCount.clamp(0, 7)).clamp(2, _maxBackoffSeconds);
    return Duration(seconds: seconds);
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  Future<int> _pushPending() async {
    final pending = HiveService.getPendingTransactions();
    if (pending.isEmpty) return 0;

    final result = await _api.pushTransactions(pending);
    int successCount = 0;

    for (final item in result.transactions) {
      if (!item.success) continue;
      if (item.action == 'delete') {
        await HiveService.purgeDeleted(item.localId);
      } else {
        await HiveService.markSynced(item.localId, item.serverId);
      }
      successCount++;
    }

    return successCount;
  }

  Future<int> _pullLatest() async {
    // Use the earliest lastSyncedAt among synced records as our cursor.
    // For a fresh device, this is null → server returns all records.
    final allLocal = HiveService.getTransactions();
    final syncedTimes = allLocal
        .where((t) => t.lastSyncedAt != null)
        .map((t) => t.lastSyncedAt!)
        .toList();

    DateTime? since;
    if (syncedTimes.isNotEmpty) {
      syncedTimes.sort();
      // Use the latest synced timestamp so we only pull deltas.
      since = syncedTimes.last;
    }

    final serverTxs = await _api.pullChanges(since);
    int count = 0;

    for (final serverTx in serverTxs) {
      final local = serverTx.toLocalTransaction();
      await HiveService.upsertFromServer(local);
      count++;
    }

    return count;
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref.watch(transactionApiServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});
