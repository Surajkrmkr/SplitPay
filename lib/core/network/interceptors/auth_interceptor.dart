import 'package:dio/dio.dart';
import '../../storage/token_storage.dart';
import '../api_constants.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  bool _isRefreshing = false;
  final List<RequestOptions> _pendingRequests = [];

  AuthInterceptor(this._dio, this._tokenStorage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
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

    // Avoid infinite loop if the refresh request itself fails
    if (options.path == ApiConstants.authRefresh) {
      await _tokenStorage.clearTokens();
      return handler.next(err);
    }

    if (_isRefreshing) {
      _pendingRequests.add(options);
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        await _tokenStorage.clearTokens();
        _isRefreshing = false;
        return handler.next(err);
      }

      final refreshResponse = await _dio.post(
        ApiConstants.authRefresh,
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: {'Authorization': null},
        ),
      );

      final newAccess = refreshResponse.data['data']?['accessToken'] as String?;
      final newRefresh =
          refreshResponse.data['data']?['refreshToken'] as String?;

      if (newAccess == null) {
        await _tokenStorage.clearTokens();
        _isRefreshing = false;
        return handler.next(err);
      }

      await _tokenStorage.saveTokens(
        access: newAccess,
        refresh: newRefresh ?? refreshToken,
      );

      // Retry original request
      options.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(options);

      // Retry any pending requests that came in during refresh
      for (final pending in _pendingRequests) {
        pending.headers['Authorization'] = 'Bearer $newAccess';
        _dio.fetch(pending);
      }
      _pendingRequests.clear();
      _isRefreshing = false;

      return handler.resolve(retryResponse);
    } catch (_) {
      await _tokenStorage.clearTokens();
      _pendingRequests.clear();
      _isRefreshing = false;
      return handler.next(err);
    }
  }
}
