import 'package:hive_flutter/hive_flutter.dart';
import '../models/budget_model.dart';
import '../models/custom_category.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';

class HiveService {
  // v1 boxes — kept for one-time migration read.
  static const _transactionsBoxV1 = 'transactions_v1';

  // v2 boxes — include sync fields.
  static const _transactionsBox = 'transactions_v2';
  static const _settingsBox = 'settings_v1';
  static const _customCategoriesBox = 'custom_categories_v1';
  static const _notificationsBox = 'notifications_v1';
  static const _budgetsBox = 'budgets_v1';

  static Future<void> init() async {
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_customCategoriesBox);
    await Hive.openBox(_notificationsBox);
    await Hive.openBox(_budgetsBox);

    // Open v2 transactions box.
    await Hive.openBox(_transactionsBox);

    // One-time migration: copy v1 rows into v2 with sync defaults.
    await _migrateTransactionsV1toV2();
  }

  static Future<void> _migrateTransactionsV1toV2() async {
    final v2Box = Hive.box(_transactionsBox);
    if (v2Box.isNotEmpty) return; // Already migrated.

    // Open v1 box to read legacy rows (may not exist on fresh installs).
    try {
      final v1Box = await Hive.openBox(_transactionsBoxV1);
      if (v1Box.isEmpty) {
        await v1Box.close();
        return;
      }

      final batch = <String, dynamic>{};
      for (final key in v1Box.keys) {
        final raw = v1Box.get(key);
        if (raw == null) continue;
        final map = Map<String, dynamic>.from(raw as Map);
        // Inject sync defaults so Transaction.fromMap() finds them.
        map['syncStatus'] = SyncStatus.pendingCreate.name;
        map['serverId'] = null;
        map['lastSyncedAt'] = null;
        map['isDeleted'] = false;
        // updatedAt falls back to createdAt inside fromMap().
        batch[key as String] = map;
      }
      await v2Box.putAll(batch);
      await v1Box.close();
    } catch (_) {
      // v1 box never existed (fresh install) — nothing to migrate.
    }
  }

  static Box get _transactions => Hive.box(_transactionsBox);
  static Box get _settings => Hive.box(_settingsBox);
  static Box get _customCats => Hive.box(_customCategoriesBox);
  static Box get _notifications => Hive.box(_notificationsBox);
  static Box get _budgets => Hive.box(_budgetsBox);

  // ─── Transactions CRUD ────────────────────────────────────────────────────

  static List<Transaction> getTransactions() {
    return _transactions.values
        .map((v) => Transaction.fromMap(v as Map))
        .where((t) => !t.isDeleted)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
}

  static List<Transaction> getPendingTransactions() {
    return _transactions.values
        .map((v) => Transaction.fromMap(v as Map))
        .where((t) => t.syncStatus.isPending)
        .toList();
  }

  static Future<void> addTransaction(Transaction tx) async {
    await _transactions.put(tx.id, tx.toMap());
  }

  static Future<void> deleteTransaction(String id) async {
    final raw = _transactions.get(id);
    if (raw == null) return;
    final tx = Transaction.fromMap(raw as Map);
    // Soft-delete: mark as pendingDelete so sync picks it up.
    final updated = tx.copyWith(
      isDeleted: true,
      syncStatus: SyncStatus.pendingDelete,
      updatedAt: DateTime.now(),
    );
    await _transactions.put(id, updated.toMap());
  }

  static Future<void> updateTransaction(Transaction tx) async {
    await _transactions.put(tx.id, tx.toMap());
  }

  /// Called by SyncService after a successful push — stores the server ID
  /// and marks the record as synced.
  static Future<void> markSynced(String localId, String serverId) async {
    final raw = _transactions.get(localId);
    if (raw == null) return;
    final tx = Transaction.fromMap(raw as Map);
    final updated = tx.copyWith(
      serverId: serverId,
      syncStatus: SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
    );
    await _transactions.put(localId, updated.toMap());
  }

  /// Called by SyncService after a successful delete push — removes the row.
  static Future<void> purgeDeleted(String localId) async {
    await _transactions.delete(localId);
  }

  /// Upserts a transaction received from the server during a pull.
  static Future<void> upsertFromServer(Transaction tx) async {
    final existing = _transactions.get(tx.id);
    if (existing != null) {
      final local = Transaction.fromMap(existing as Map);
      // Last-write-wins: only overwrite if server is newer.
      if (local.syncStatus == SyncStatus.synced ||
          tx.updatedAt.isAfter(local.updatedAt)) {
        await _transactions.put(tx.id, tx.toMap());
      }
    } else {
      await _transactions.put(tx.id, tx.toMap());
    }
  }

  // ─── Custom Categories CRUD ───────────────────────────────────────────────

  static List<CustomCategory> getCustomCategories() {
    return _customCats.values
        .map((v) => CustomCategory.fromMap(v as Map))
        .toList();
  }

  static Future<void> saveCustomCategory(CustomCategory cat) async {
    await _customCats.put(cat.id, cat.toMap());
  }

  static Future<void> deleteCustomCategory(String id) async {
    await _customCats.delete(id);
  }

  // ─── Notifications CRUD ───────────────────────────────────────────────────

  static List<NotificationModel> getNotifications() {
    return _notifications.values
        .map((v) => NotificationModel.fromHive(v as Map))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> saveNotification(NotificationModel n) async {
    await _notifications.put(n.id, n.toHive());
  }

  static Future<void> saveNotifications(List<NotificationModel> list) async {
    final map = {for (final n in list) n.id: n.toHive()};
    await _notifications.putAll(map);
  }

  static Future<void> markNotificationRead(String id) async {
    final raw = _notifications.get(id);
    if (raw == null) return;
    final n = NotificationModel.fromHive(raw as Map).copyWith(isRead: true);
    await _notifications.put(id, n.toHive());
  }

  static Future<void> markAllNotificationsRead() async {
    final updates = <String, dynamic>{};
    for (final key in _notifications.keys) {
      final raw = _notifications.get(key);
      if (raw == null) continue;
      final n = NotificationModel.fromHive(raw as Map).copyWith(isRead: true);
      updates[key as String] = n.toHive();
    }
    await _notifications.putAll(updates);
  }

  static Future<void> deleteNotification(String id) async {
    await _notifications.delete(id);
  }

  static Future<void> clearAllNotifications() async {
    await _notifications.clear();
  }

  static int getUnreadCount() {
    return _notifications.values
        .where((v) => (v as Map)['isRead'] == false)
        .length;
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  /// Wipes all user-specific data on logout / session expiry.
  /// Settings are intentionally preserved (app-level prefs, not user data).
  static Future<void> clearUserData() async {
    await Future.wait([
      _transactions.clear(),
      _customCats.clear(),
      _notifications.clear(),
      _budgets.clear(),
    ]);
  }

  // ─── Settings ─────────────────────────────────────────────────────────────

  static T? getSetting<T>(String key) => _settings.get(key) as T?;
  static Future<void> setSetting(String key, dynamic value) =>
      _settings.put(key, value);

  // ─── Budgets CRUD ─────────────────────────────────────────────────────────

  static List<Budget> getBudgets() {
    return _budgets.values
        .map((v) => Budget.fromMap(v as Map))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> addBudget(Budget budget) async {
    await _budgets.put(budget.id, budget.toMap());
  }

  static Future<void> updateBudget(Budget budget) async {
    await _budgets.put(budget.id, budget.toMap());
  }

  static Future<void> deleteBudget(String id) async {
    await _budgets.delete(id);
  }
}
