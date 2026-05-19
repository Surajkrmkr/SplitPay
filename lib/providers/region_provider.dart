import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/region_service.dart';
import 'settings_provider.dart';

/// Whether the current device should display UPI payment options.
/// Reacts to currency changes (₹ triggers UPI even if locale is non-IN).
final showUpiProvider = Provider<bool>((ref) {
  final currency = ref.watch(currencyProvider);
  return RegionService.shouldShowUpi(currency: currency);
});

/// True when device locale appears to be India-based.
final isIndianLocaleProvider = Provider<bool>((_) => RegionService.isIndianLocale);
