import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Styled back button used across the app — matches the chip used in
/// [AnalyticsScreen]'s header. Renders nothing when the route can't be
/// popped, so it's safe to drop into top-level shell tabs.
class AppBackButton extends StatelessWidget {
  /// Override the default `Navigator.pop()` behavior — useful for screens
  /// that need to confirm before leaving.
  final VoidCallback? onTap;

  /// When true, returns `SizedBox.shrink()` instead of nothing if there's no
  /// route to pop. Useful inside Rows where you want the layout consistent.
  final bool keepSpaceWhenHidden;

  const AppBackButton({
    super.key,
    this.onTap,
    this.keepSpaceWhenHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();

    if (!canPop) {
      return keepSpaceWhenHidden
          ? const SizedBox(width: 36, height: 36)
          : const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 20,
          color: isDark ? Colors.white : AppColors.textLight,
        ),
      ),
    );
  }
}
