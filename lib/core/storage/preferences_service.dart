import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static T? get<T>(String key) {
    final value = _prefs.get(key);
    if (value is T) return value;
    return null;
  }

  static List<String>? getStringList(String key) => _prefs.getStringList(key);

  static Future<void> set(String key, dynamic value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    }
  }

  static Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  /// Clears user-specific persisted data on logout.
  /// App-level prefs (theme, currency, onboarding) are intentionally preserved.
  static Future<void> clearUserData() async {
    await _prefs.remove('budgets');
  }
}
