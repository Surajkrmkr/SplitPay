import 'package:dio/dio.dart';

class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  factory AppException.network() => const AppException(
        'No internet connection. Please check your network and try again.',
      );

  factory AppException.unauthorized() => const AppException(
        'Session expired. Please sign in again.',
        statusCode: 401,
      );

  factory AppException.serverError([String? msg]) => AppException(
        msg ?? 'Something went wrong on our end. Please try again later.',
        statusCode: 500,
      );

  factory AppException.notFound([String? resource]) => AppException(
        resource != null
            ? '$resource not found.'
            : 'The requested resource was not found.',
        statusCode: 404,
      );

  factory AppException.unknown() => const AppException(
        'An unexpected error occurred. Please try again.',
      );

  factory AppException.timeout() => const AppException(
        'Request timed out. Please check your connection and try again.',
      );

  factory AppException.badRequest([String? msg]) => AppException(
        msg ?? 'Invalid request. Please check your input and try again.',
        statusCode: 400,
      );

  factory AppException.forbidden([String? msg]) => AppException(
        msg ?? 'You do not have permission to perform this action.',
        statusCode: 403,
      );

  /// Maps a raw [DioException] to a user-facing [AppException]. Shared by
  /// [ErrorInterceptor] (so every network error already carries a friendly
  /// message by the time it reaches app code) and [friendlyErrorMessage]
  /// (as a fallback for DioExceptions the interceptor never saw).
  factory AppException.fromDioException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException.timeout();

      case DioExceptionType.connectionError:
        return AppException.network();

      case DioExceptionType.badResponse:
        return _fromStatusCode(err);

      case DioExceptionType.cancel:
        return const AppException('Request was cancelled.');

      default:
        if (err.error is AppException) return err.error as AppException;
        return AppException.unknown();
    }
  }

  static AppException _fromStatusCode(DioException err) {
    final statusCode = err.response?.statusCode;
    final serverMessage = _extractServerMessage(err.response);

    switch (statusCode) {
      case 400:
        return AppException.badRequest(serverMessage);
      case 401:
        return AppException.unauthorized();
      case 403:
        return AppException.forbidden(serverMessage);
      case 404:
        return AppException.notFound(serverMessage);
      case int s when s >= 500:
        return AppException.serverError(serverMessage);
      default:
        return AppException(
          serverMessage ?? 'Unexpected error (HTTP $statusCode).',
          statusCode: statusCode,
        );
    }
  }

  static String? _extractServerMessage(Response? response) {
    try {
      final data = response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] as String?;
      }
    } catch (_) {}
    return null;
  }

  @override
  String toString() => message;
}

/// Converts any caught error into a short, user-facing message — never the
/// raw exception/stack-trace text (e.g. "DioException [badResponse]: ...").
/// Use this everywhere an error reaches the UI (snackbars, inline error
/// states, dialogs); leave raw `error`/`stackTrace` values for logging only.
String friendlyErrorMessage(Object error) {
  if (error is AppException) return error.message;
  if (error is DioException) {
    final wrapped = error.error;
    if (wrapped is AppException) return wrapped.message;
    return AppException.fromDioException(error).message;
  }
  return 'Something went wrong. Please try again.';
}
