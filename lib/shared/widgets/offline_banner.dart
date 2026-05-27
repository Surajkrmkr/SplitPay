import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/sync_service.dart';

/// A slim banner shown at the top of screens when the device is offline
/// or a sync error has occurred.  Dismisses automatically when the state
/// returns to idle/syncing.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);

    final visible =
        syncState == SyncState.offline || syncState == SyncState.error;

    return AnimatedSwitcher(
      duration: 300.ms,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        child: child,
      ),
      child: visible
          ? _BannerContent(key: const ValueKey('banner'), state: syncState)
          : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final SyncState state;
  const _BannerContent({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isOffline = state == SyncState.offline;
    final color = isOffline ? AppColors.textSecondary : AppColors.expense;
    final icon = isOffline ? Icons.wifi_off_rounded : Icons.sync_problem_rounded;
    final message = isOffline
        ? 'You\'re offline — changes will sync when reconnected'
        : 'Sync failed — will retry automatically';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
