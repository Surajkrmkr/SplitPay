import 'package:hive_flutter/hive_flutter.dart';
import '../models/custom_category.dart';
import '../models/transaction_model.dart';

class HiveService {
  static const _transactionsBox = 'transactions_v1';
  static const _settingsBox = 'settings_v1';
  static const _customCategoriesBox = 'custom_categories_v1';

  static Future<void> init() async {
    await Hive.openBox(_transactionsBox);
    await Hive.openBox(_settingsBox);
    await Hive.openBox(_customCategoriesBox);
  }

  static Box get _transactions => Hive.box(_transactionsBox);
  static Box get _settings => Hive.box(_settingsBox);
  static Box get _customCats => Hive.box(_customCategoriesBox);

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

  // Settings
  static T? getSetting<T>(String key) => _settings.get(key) as T?;
  static Future<void> setSetting(String key, dynamic value) =>
      _settings.put(key, value);
}
