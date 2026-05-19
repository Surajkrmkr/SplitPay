import 'package:dio/dio.dart';
import '../../errors/app_exception.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = _mapDioException(err);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: appException,
        message: appException.message,
      ),
    );
  }

  AppException _mapDioException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException.timeout();

      case DioExceptionType.connectionError:
        return AppException.network();

      case DioExceptionType.badResponse:
        return _mapStatusCode(err);

      case DioExceptionType.cancel:
        return const AppException('Request was cancelled.');

      default:
        if (err.error is AppException) return err.error as AppException;
        return AppException.unknown();
    }
  }

  AppException _mapStatusCode(DioException err) {
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

  String? _extractServerMessage(Response? response) {
    try {
      final data = response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
