import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/interceptors/auth_interceptor.dart';
import '../models/notification_model.dart';
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
      // Called during logout — a 401 here must not trigger auto-refresh/reauth,
      // which would race with the logout flow's own token clearing.
      await _dio.delete(
        ApiConstants.notificationsRegisterToken,
        data: {'fcmToken': token},
        options: Options(extra: {AuthInterceptor.skipAuthHandling: true}),
      );
    } catch (_) {}
  }

  // ── Notifications API ─────────────────────────────────────────────────────

  Future<List<NotificationModel>> getNotifications({int page = 1}) async {
    final res = await _dio.get(
      ApiConstants.notifications,
      queryParameters: {'page': page, 'limit': 30},
    );
    return (res.data['data'] as List<dynamic>)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.patch(ApiConstants.notificationRead(id));
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _dio.patch(ApiConstants.notificationsReadAll);
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete(ApiConstants.notificationById(id));
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    try {
      await _dio.delete(ApiConstants.notifications);
    } catch (_) {}
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(dioProvider));
});
