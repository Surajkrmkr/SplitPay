import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/sync_service.dart';

/// A small chip that shows the current sync state and last-synced timestamp.
/// Tapping it triggers a manual sync.
class SyncStatusIndicator extends ConsumerWidget {
  final VoidCallback? onSyncTap;

  const SyncStatusIndicator({super.key, this.onSyncTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final lastSynced = ref.watch(lastSyncedAtProvider);

    return GestureDetector(
      onTap: syncState == SyncState.syncing ? null : onSyncTap,
      child: AnimatedSwitcher(
        duration: 250.ms,
        child: _Chip(
          key: ValueKey(syncState),
          state: syncState,
          lastSynced: lastSynced,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final SyncState state;
  final DateTime? lastSynced;

  const _Chip({super.key, required this.state, required this.lastSynced});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, label, color) = _content();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == SyncState.syncing)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            )
          else
            Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _content() {
    switch (state) {
      case SyncState.syncing:
        return (Icons.sync_rounded, 'Syncing…', AppColors.primary);
      case SyncState.offline:
        return (Icons.wifi_off_rounded, 'Offline', AppColors.textSecondary);
      case SyncState.error:
        return (Icons.sync_problem_rounded, 'Sync failed', AppColors.expense);
      case SyncState.idle:
        if (lastSynced == null) {
          return (Icons.sync_rounded, 'Not synced', AppColors.textTertiary);
        }
        return (
          Icons.check_circle_outline_rounded,
          'Synced ${_ago(lastSynced!)}',
          AppColors.income,
        );
    }
  }

  String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM').format(t);
  }
}
