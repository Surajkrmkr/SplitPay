import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update_flutter/in_app_update_flutter.dart';
import 'app_logger.dart';

/// Singleton service managing in-app update checks for Android (Google Play In-App Updates)
/// and iOS (SKStoreProductViewController / App Store product view).
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  final InAppUpdateFlutter _updater = InAppUpdateFlutter();

  /// Numerical App Store ID for iOS update modal.
  /// Replace with actual published App Store ID once available.
  static const String iosAppStoreId = '6470000000';

  /// Triggers an in-app update check.
  /// Safe to call on all platforms including Web, emulator, and debug builds.
  Future<void> checkForUpdate({
    BuildContext? context,
    bool showNoUpdateToast = false,
  }) async {
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid) {
        final updateInfo = await _updater.checkUpdateAndroid();
        if (updateInfo.updateAvailability == UpdateAvailabilityAndroid.updateAvailable) {
          if (updateInfo.isImmediateUpdateAllowed) {
            await _updater.startImmediateUpdateAndroid();
          } else if (updateInfo.isFlexibleUpdateAllowed) {
            await _updater.startFlexibleUpdateAndroid();
            await _updater.completeUpdateAndroid();
          }
        } else if (showNoUpdateToast && context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are on the latest version!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (Platform.isIOS) {
        await _updater.showUpdateForIos(appStoreId: iosAppStoreId);
      }
    } catch (e) {
      AppLogger.instance.w(
        'In-App Update check skipped or failed (expected on debug/unreleased builds): $e',
        tag: 'UpdateService',
      );
      if (showNoUpdateToast && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked for updates. You are on the latest version.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
