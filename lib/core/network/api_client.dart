import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_constants.dart';
import 'auth_events.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/log_interceptor.dart';
import '../storage/token_storage.dart';

class ApiClient {
  static Dio create(
    TokenStorage tokenStorage, {
    VoidCallback? onSessionExpired,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(
      AuthInterceptor(dio, tokenStorage, onSessionExpired: onSessionExpired),
    );
    dio.interceptors.add(ErrorInterceptor());
    if (kDebugMode) {
      dio.interceptors.add(PrettyLogInterceptor());
    }
    return dio;
  }
}

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient.create(
    tokenStorage,
    onSessionExpired: () {
      ref.read(sessionExpiredProvider.notifier).state++;
    },
  );
});
