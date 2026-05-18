import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_constants.dart';
import '../models/notification_model.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  // ── Token Management ──────────────────────────────────────────────────────

  Future<void> registerToken({
    required String userId,
    required String fcmToken,
  }) async {
    try {
      await _dio.post(
        ApiConstants.notificationsRegisterToken,
        data: {
          'userId': userId,
          'fcmToken': fcmToken,
          'deviceType': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (_) {
      // Non-fatal — token will re-register on next launch
    }
  }

  Future<void> unregisterToken() async {
    try {
      final token = await NotificationService.instance.getToken();
      if (token == null) return;
      await _dio.delete(
        ApiConstants.notificationsRegisterToken,
        data: {'fcmToken': token},
      );
    } catch (_) {}
  }

  // ── Notifications API ─────────────────────────────────────────────────────

  /// Fetches from API and syncs local cache. Falls back to cache on error.
  Future<List<NotificationModel>> getNotifications({int page = 1}) async {
    try {
      final res = await _dio.get(
        ApiConstants.notifications,
        queryParameters: {'page': page, 'limit': 30},
      );
      final items = (res.data['data'] as List<dynamic>)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (page == 1) {
        // Replace cache with fresh data on first page
        await HiveService.saveNotifications(items);
      }
      return items;
    } on DioException {
      // Return cached data so the screen works offline
      return HiveService.getNotifications();
    }
  }

  Future<void> markRead(String id) async {
    await HiveService.markNotificationRead(id);
    try {
      await _dio.patch(ApiConstants.notificationRead(id));
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    await HiveService.markAllNotificationsRead();
    try {
      await _dio.patch(ApiConstants.notificationsReadAll);
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    await HiveService.deleteNotification(id);
    try {
      await _dio.delete(ApiConstants.notificationById(id));
    } catch (_) {}
  }

  /// Prepend a locally-received FCM notification to the cache.
  Future<void> cacheIncoming(NotificationModel notification) async {
    await HiveService.saveNotification(notification);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(dioProvider));
});
