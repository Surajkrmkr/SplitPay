import 'package:flutter/material.dart';

import '../../router/app_router.dart';
import '../../shared/dialogs/rate_app_dialog.dart';
import '../storage/preferences_service.dart';
import 'app_logger.dart';

class RateAppService {
  static const _keyExpenseCount = 'user_personal_expense_count';
  static const _keyHasRated = 'user_has_rated_app';

  /// Called whenever a personal transaction/expense is successfully added.
  /// Increments the personal expense counter and presents the rating popup
  /// when the user reaches 2 or more expenses.
  static Future<void> checkAndPromptRating([BuildContext? context]) async {
    final hasRated = PreferencesService.get<bool>(_keyHasRated) ?? false;
    if (hasRated) return;

    final currentCount = (PreferencesService.get<int>(_keyExpenseCount) ?? 0) + 1;
    await PreferencesService.set(_keyExpenseCount, currentCount);

    AppLogger.instance.i('Personal expense count: $currentCount', tag: 'RateApp');

    if (currentCount >= 2) {
      await Future.delayed(const Duration(milliseconds: 400));

      // Resolve a valid, mounted context (falling back to rootNavigatorKey)
      final targetContext = (context != null && context.mounted)
          ? context
          : rootNavigatorKey.currentContext;

      if (targetContext != null && targetContext.mounted) {
        await RateAppDialog.show(targetContext);
      }
    }
  }
}
