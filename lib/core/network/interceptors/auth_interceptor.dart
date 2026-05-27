import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../storage/token_storage.dart';
import '../api_constants.dart';

class AuthInterceptor extends Interceptor {
  // Marker on RequestOptions.extra so we never retry the same request twice.
  static const _retryMarker = '__auth_retry__';

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final VoidCallback? onSessionExpired;

  // Single in-flight refresh shared across concurrent 401s.
  Completer<String?>? _refreshCompleter;

  AuthInterceptor(
    this._dio,
    this._tokenStorage, {
    this.onSessionExpired,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Auth endpoints must not carry a (possibly stale) access token —
    // the refresh endpoint authenticates via the refresh token in the body,
    // and the login endpoint via the Google ID token.
    if (_isAuthEndpoint(options)) {
      options.headers.remove('Authorization');
      return handler.next(options);
    }

    final token = await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final options = err.requestOptions;

    // A 401 from the refresh endpoint itself means the refresh token is dead.
    if (_isRefreshEndpoint(options)) {
      await _invalidateSession();
      return handler.next(err);
    }

    // Don't refresh on login — it needs valid credentials, not a token swap.
    if (_isLoginEndpoint(options)) {
      return handler.next(err);
    }

    // One retry per request, max.
    if (options.extra[_retryMarker] == true) {
      return handler.next(err);
    }

    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _invalidateSession();
      return handler.next(err);
    }

    final newAccess = await _refreshAccessToken(refreshToken);
    if (newAccess == null || newAccess.isEmpty) {
      return handler.next(err);
    }

    try {
      options.extra[_retryMarker] = true;
      options.headers['Authorization'] = 'Bearer $newAccess';
      final response = await _dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    }
  }

  /// Posts to the refresh endpoint and persists the new tokens.
  /// Concurrent callers share a single in-flight request via [_refreshCompleter].
  Future<String?> _refreshAccessToken(String refreshToken) async {
    final inflight = _refreshCompleter;
    if (inflight != null) return inflight.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final response = await _dio.post(
        ApiConstants.authRefresh,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data is Map<String, dynamic>
          ? response.data['data'] as Map<String, dynamic>?
          : null;
      final newAccess = data?['accessToken'] as String?;
      final newRefresh = data?['refreshToken'] as String?;

      if (newAccess == null || newAccess.isEmpty) {
        await _invalidateSession();
        completer.complete(null);
        return null;
      }

      await _tokenStorage.saveTokens(
        access: newAccess,
        refresh: (newRefresh != null && newRefresh.isNotEmpty)
            ? newRefresh
            : refreshToken,
      );
      completer.complete(newAccess);
      return newAccess;
    } catch (_) {
      await _invalidateSession();
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _invalidateSession() async {
    await _tokenStorage.clearTokens();
    onSessionExpired?.call();
  }

  bool _isAuthEndpoint(RequestOptions options) =>
      _isRefreshEndpoint(options) || _isLoginEndpoint(options);

  bool _isRefreshEndpoint(RequestOptions options) =>
      options.path == ApiConstants.authRefresh ||
      options.uri.path.endsWith(ApiConstants.authRefresh);

  bool _isLoginEndpoint(RequestOptions options) =>
      options.path == ApiConstants.authGoogle ||
      options.uri.path.endsWith(ApiConstants.authGoogle);
}
