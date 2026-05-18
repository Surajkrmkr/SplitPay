import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/notification_model.dart';
import '../data/repositories/notification_repository.dart';
import '../data/services/hive_service.dart';
import '../data/services/notification_service.dart';

// ── Notifications List ────────────────────────────────────────────────────────

class NotificationsNotifier
    extends AsyncNotifier<List<NotificationModel>> {
  StreamSubscription<NotificationModel>? _foregroundSub;

  @override
  Future<List<NotificationModel>> build() async {
    // Load from cache immediately for instant UI
    final cached = HiveService.getNotifications();

    // Subscribe to foreground FCM messages and prepend them live
    _foregroundSub?.cancel();
    _foregroundSub = NotificationService.instance.foregroundStream.listen(
      _onForegroundNotification,
    );
    ref.onDispose(() => _foregroundSub?.cancel());

    // Fetch fresh from API in background
    _fetchFromApi();

    return cached;
  }

  Future<void> _fetchFromApi() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final fresh = await repo.getNotifications();
      state = AsyncValue.data(fresh);
    } catch (_) {
      // Cache already shown — no need to update state on error
    }
  }

  void _onForegroundNotification(NotificationModel notification) {
    final current = state.valueOrNull ?? [];
    // Avoid duplicates
    if (current.any((n) => n.id == notification.id)) return;
    state = AsyncValue.data([notification, ...current]);
    ref.read(notificationRepositoryProvider).cacheIncoming(notification);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final items = await repo.getNotifications();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
    );
    await ref.read(notificationRepositoryProvider).markRead(id);
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((n) => n.copyWith(isRead: true)).toList(),
    );
    await ref.read(notificationRepositoryProvider).markAllRead();
  }

  Future<void> delete(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((n) => n.id != id).toList());
    await ref.read(notificationRepositoryProvider).delete(id);
  }

  Future<void> deleteAll() async {
    state = const AsyncValue.data([]);
    await ref.read(notificationRepositoryProvider).deleteAll();
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
  NotificationsNotifier.new,
);

// ── Derived Providers ─────────────────────────────────────────────────────────

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];
  return notifications.where((n) => !n.isRead).length;
});

final hasUnreadProvider = Provider<bool>((ref) {
  return ref.watch(unreadCountProvider) > 0;
});

// ── Foreground notification stream (for in-app banner) ────────────────────────

final foregroundNotificationProvider =
    StreamProvider<NotificationModel>((ref) {
  return NotificationService.instance.foregroundStream;
});

// ── Tap navigation stream ─────────────────────────────────────────────────────

final notificationTapProvider = StreamProvider<NotificationModel>((ref) {
  return NotificationService.instance.tapStream;
});
