import 'package:hive_flutter/hive_flutter.dart';
import '../models/custom_category.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';

class HiveService {
  static const _transactionsBox = 'transactions_v1';
  static const _settingsBox = 'settings_v1';
  static const _customCategoriesBox = 'custom_categories_v1';
  static const _notificationsBox = 'notifications_v1';

  static Future<void> init() async {
    await Hive.openBox(_transactionsBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_customCategoriesBox);
    await Hive.openBox(_notificationsBox);
  }

  static Box get _transactions => Hive.box(_transactionsBox);
  static Box get _settings => Hive.box(_settingsBox);
  static Box get _customCats => Hive.box(_customCategoriesBox);
  static Box get _notifications => Hive.box(_notificationsBox);

  // Transactions CRUD
  static List<Transaction> getTransactions() {
    return _transactions.values
        .map((v) => Transaction.fromMap(v as Map))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> addTransaction(Transaction tx) async {
    await _transactions.put(tx.id, tx.toMap());
  }

  static Future<void> deleteTransaction(String id) async {
    await _transactions.delete(id);
  }

  static Future<void> updateTransaction(Transaction tx) async {
    await _transactions.put(tx.id, tx.toMap());
  }

  // Custom Categories CRUD
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

  // Notifications CRUD
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

  // Settings
  static T? getSetting<T>(String key) => _settings.get(key) as T?;
  static Future<void> setSetting(String key, dynamic value) =>
      _settings.put(key, value);
}
