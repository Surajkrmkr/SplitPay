import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';

class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final firstName = user?.name.split(' ').first ?? 'there';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting, $firstName',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textLightSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Dashboard',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '✦',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideX(
                      begin: -0.1,
                      end: 0,
                      delay: 100.ms,
                      duration: 500.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ],
            ),
          ),
          _NotificationBell(),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.notifications_outlined,
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textLightSecondary,
            size: 22,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: bgColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn().scale(curve: Curves.elasticOut);
  }
}
