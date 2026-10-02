import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notification_provider.dart';

String greetingForLocalTime(DateTime localTime) {
  final hour = localTime.hour;
  if (hour >= 5 && hour < 12) return 'Good Morning';
  if (hour >= 12 && hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

class GreetingHeader extends ConsumerStatefulWidget {
  const GreetingHeader({super.key});

  @override
  ConsumerState<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends ConsumerState<GreetingHeader>
    with WidgetsBindingObserver {
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now().toLocal();
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshLocalTime(),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshLocalTime();
  }

  void _refreshLocalTime() {
    if (!mounted) return;
    setState(() => _now = DateTime.now().toLocal());
  }

  String get _greeting {
    return greetingForLocalTime(_now);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
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
                        color: primary,
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
          const NotificationBell(),
        ],
      ),
    );
  }
}

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shake = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    // Shake the bell when a foreground notification arrives
    ref.listenManual(foregroundNotificationProvider, (_, next) {
      if (next.hasValue) _shakeController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final unread = ref.watch(unreadCountProvider);
    final bgColor = isDark
        ? (Theme.of(context).cardTheme.color ?? AppColors.darkCard)
        : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final angle =
              (_shake.value * 0.3) * ((_shakeController.value < 0.5) ? 1 : -1);
          return Transform.rotate(angle: angle, child: child);
        },
        child: Container(
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
                unread > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_outlined,
                color: unread > 0
                    ? primary
                    : (isDark
                        ? AppColors.textSecondary
                        : AppColors.textLightSecondary),
                size: 22,
              ),
              if (unread > 0)
                Positioned(
                  top: 7,
                  right: 7,
                  child: _Badge(count: unread, bgColor: bgColor),
                ),
            ],
          ),
        ),
      ),
    ).animate(delay: 300.ms).fadeIn().scale(curve: Curves.elasticOut);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.bgColor});

  final int count;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: AppColors.expense,
        shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: count > 9 ? BorderRadius.circular(8) : null,
        border: Border.all(color: bgColor, width: 1.5),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    ).animate().scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          curve: Curves.elasticOut,
          duration: 400.ms,
        );
  }
}
