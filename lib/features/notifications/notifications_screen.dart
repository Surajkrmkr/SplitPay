import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../shared/widgets/app_back_button.dart';
import 'widgets/notification_card.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).markAllRead();
    });
  }

  void _onTap(NotificationModel n) {
    final route = n.type.routeFor(n.groupId);
    context.push(route);
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 12),
                    const Text('Clear All Notifications', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('This cannot be undone', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'All notifications will be permanently removed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textLight, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => ctx.pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.textSecondary : AppColors.textLightSecondary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => ctx.pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.expense,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Clear All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed == true) {
      ref.read(notificationsProvider.notifier).deleteAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncNotifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: _buildAppBar(context, isDark, asyncNotifications),
      body: asyncNotifications.when(
        loading: () => _SkeletonList(),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (notifications) {
          if (notifications.isEmpty) return const _EmptyState();
          return _NotificationList(
            notifications: notifications,
            onTap: _onTap,
            onDismiss: (id) =>
                ref.read(notificationsProvider.notifier).delete(id),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    bool isDark,
    AsyncValue<List<NotificationModel>> async,
  ) {
    final unread = async.valueOrNull?.where((n) => !n.isRead).length ?? 0;
    return AppBar(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 56,
      leading: const Padding(
        padding: EdgeInsets.only(left: 16),
        child: Center(child: AppBackButton()),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notifications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (unread > 0)
            Text(
              '$unread unread',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      actions: [
        if (async.valueOrNull?.any((n) => !n.isRead) == true)
          TextButton(
            onPressed: () =>
                ref.read(notificationsProvider.notifier).markAllRead(),
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (async.valueOrNull?.isNotEmpty == true)
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            color: AppColors.expense,
            tooltip: 'Clear all',
            onPressed: () => _confirmClearAll(context),
          ),
      ],
    );
  }
}

// ── Notification List with sections ──────────────────────────────────────────

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.notifications,
    required this.onTap,
    required this.onDismiss,
  });

  final List<NotificationModel> notifications;
  final void Function(NotificationModel) onTap;
  final void Function(String id) onDismiss;

  @override
  Widget build(BuildContext context) {
    final today = notifications.where((n) => n.isToday).toList();
    final yesterday = notifications.where((n) => n.isYesterday).toList();
    final earlier = notifications
        .where((n) => !n.isToday && !n.isYesterday)
        .toList();

    int globalIndex = 0;

    final items = <Widget>[];

    if (today.isNotEmpty) {
      items.add(const NotificationSectionHeader(label: 'TODAY'));
      for (final n in today) {
        final i = globalIndex++;
        items.add(NotificationCard(
          notification: n,
          onTap: () => onTap(n),
          onDismiss: () => onDismiss(n.id),
          index: i,
        ));
      }
    }

    if (yesterday.isNotEmpty) {
      items.add(const NotificationSectionHeader(label: 'YESTERDAY'));
      for (final n in yesterday) {
        final i = globalIndex++;
        items.add(NotificationCard(
          notification: n,
          onTap: () => onTap(n),
          onDismiss: () => onDismiss(n.id),
          index: i,
        ));
      }
    }

    if (earlier.isNotEmpty) {
      items.add(const NotificationSectionHeader(label: 'EARLIER'));
      for (final n in earlier) {
        final i = globalIndex++;
        items.add(NotificationCard(
          notification: n,
          onTap: () => onTap(n),
          onDismiss: () => onDismiss(n.id),
          index: i,
        ));
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      children: items,
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 36,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No notifications yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? AppColors.textPrimary : AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Group activity, settlements, and\nreminders will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textLightSecondary,
              height: 1.5,
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .scale(begin: const Offset(0.9, 0.9), duration: 400.ms),
    );
  }
}

// ── Skeleton Loading ──────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12),
      children: List.generate(
        7,
        (i) => NotificationCardSkeleton(index: i),
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Couldn\'t load notifications',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
