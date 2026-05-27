import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/hive_service.dart';
import '../services/sync_service.dart';

/// Offline-first repository for personal transactions.
///
/// All mutations write to Hive first, then schedule a background sync.
/// Reads always come from Hive so the UI is never blocked by network.
class TransactionRepository {
  final SyncService _sync;
  final void Function(SyncState) _onSyncState;
  final void Function(DateTime) _onSyncSuccess;

  TransactionRepository(
    this._sync,
    this._onSyncState,
    this._onSyncSuccess,
  );

  // ─── Reads ────────────────────────────────────────────────────────────────

  List<Transaction> getAll() => HiveService.getTransactions();

  List<Transaction> getPending() => HiveService.getPendingTransactions();

  // ─── Writes ───────────────────────────────────────────────────────────────

  Future<void> add(Transaction tx) async {
    final toSave = tx.copyWith(
      syncStatus: SyncStatus.pendingCreate,
      updatedAt: DateTime.now(),
    );
    await HiveService.addTransaction(toSave);
    _sync.scheduleSync(_onSyncState, onSyncSuccess: _onSyncSuccess);
  }

  Future<void> update(Transaction tx) async {
    final toSave = tx.copyWith(
      syncStatus: tx.syncStatus == SyncStatus.pendingCreate
          ? SyncStatus.pendingCreate
          : SyncStatus.pendingUpdate,
      updatedAt: DateTime.now(),
    );
    await HiveService.updateTransaction(toSave);
    _sync.scheduleSync(_onSyncState, onSyncSuccess: _onSyncSuccess);
  }

  Future<void> delete(String id) async {
    await HiveService.deleteTransaction(id);
    _sync.scheduleSync(_onSyncState, onSyncSuccess: _onSyncSuccess);
  }

  // ─── Sync ─────────────────────────────────────────────────────────────────

  /// Manual full sync — called by pull-to-refresh or app foreground events.
  Future<SyncResult> syncNow() => _sync.sync(_onSyncState);
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final sync = ref.watch(syncServiceProvider);
  final syncNotifier = ref.read(syncStateProvider.notifier);

  void onSyncSuccess(DateTime t) {
    // Update the in-memory provider so the SyncStatusIndicator re-renders.
    ref.read(lastSyncedAtProvider.notifier).state = t;
    // Also persist so it survives app restarts.
    HiveService.setSetting('lastSyncedAt', t.millisecondsSinceEpoch);
  }

  return TransactionRepository(sync, syncNotifier.update, onSyncSuccess);
});

// ─── Sync state notifier ──────────────────────────────────────────────────────

class SyncStateNotifier extends StateNotifier<SyncState> {
  SyncStateNotifier() : super(SyncState.idle);

  void update(SyncState s) => state = s;
}

final syncStateProvider =
    StateNotifierProvider<SyncStateNotifier, SyncState>(
  (_) => SyncStateNotifier(),
);

/// Last successful sync timestamp — persisted in Hive settings.
final lastSyncedAtProvider = StateProvider<DateTime?>((ref) {
  final stored = HiveService.getSetting<int>('lastSyncedAt');
  return stored != null ? DateTime.fromMillisecondsSinceEpoch(stored) : null;
});
