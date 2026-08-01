import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/storage/preferences_service.dart';
import '../../core/services/app_logger.dart';

class RateAppDialog extends StatefulWidget {
  const RateAppDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const RateAppDialog(),
    );
  }

  @override
  State<RateAppDialog> createState() => _RateAppDialogState();
}

class _RateAppDialogState extends State<RateAppDialog> {
  int _selectedStars = 5;

  Future<void> _onRatePressed() async {
    await PreferencesService.set('user_has_rated_app', true);
    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Thank you for your feedback! ❤️'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primary,
      ),
    );

    // Launch store review URL if possible
    try {
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      final storeUrl = isIOS
          ? 'https://apps.apple.com/app/id6400000000'
          : 'https://play.google.com/store/apps/details?id=com.splitpay.expensetracker';
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      AppLogger.instance.e('Error launching store URL: $e', tag: 'RateApp');
    }
  }

  Future<void> _onRemindLater() async {
    // Reset count so it asks again after 5 more expenses
    await PreferencesService.set('user_personal_expense_count', -3);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onNoThanks() async {
    await PreferencesService.set('user_has_rated_app', true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final storeName = isIOS ? 'App Store' : 'Play Store';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      elevation: 10,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/icon/app_icon_transparent.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
            ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 18),

            // Title
            Text(
              'Enjoying SplitPay?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textLight,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              'Take a second to rate your experience and help us improve SplitPay.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            // 5-Star Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                final isSelected = starNumber <= _selectedStars;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStars = starNumber),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: isSelected
                          ? const Color(0xFFFFB800)
                          : AppColors.textTertiary,
                      size: 34,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Submit / Rate Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _onRatePressed,
                child: Text(
                  _selectedStars >= 4 ? 'Rate on $storeName' : 'Submit Rating',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Action links row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: _onRemindLater,
                  child: Text(
                    'Remind Later',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                TextButton(
                  onPressed: _onNoThanks,
                  child: Text(
                    'No Thanks',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
