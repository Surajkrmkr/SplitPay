import 'dart:io';

/// Determines if UPI payment features should be surfaced.
///
/// UPI is India-specific and Android-only. We enable it when:
///   • the device is Android, AND
///   • the device locale is Indian (en_IN, hi_IN, etc.) OR
///     the app currency is set to ₹ (INR).
class RegionService {
  static bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  static bool get isIndianLocale {
    try {
      final locale = Platform.localeName; // e.g. 'en_IN', 'hi_IN'
      return locale.contains('_IN') ||
          locale.toUpperCase().startsWith('IN_') ||
          locale.toUpperCase() == 'IN';
    } catch (_) {
      return false;
    }
  }

  static bool isIndianCurrency(String currency) => currency == '₹';

  /// Returns true when UPI payment options should be shown.
  static bool shouldShowUpi({required String currency}) {
    if (!_isAndroid) return false;
    return isIndianLocale || isIndianCurrency(currency);
  }
}
