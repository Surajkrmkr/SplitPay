import 'dart:io';

/// Determines if UPI payment features should be surfaced.
///
/// UPI is India-specific but not Android-only — the `upi_pro_sdk` plugin
/// backing it has a native iOS implementation that launches UPI apps via
/// their own custom URL schemes (gpay://, phonepe://, etc). We enable it when:
///   • the device locale is Indian (en_IN, hi_IN, etc.) OR
///   • the app currency is set to ₹ (INR).
class RegionService {
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
    return isIndianLocale || isIndianCurrency(currency);
  }
}
