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

  factory AppException.forbidden() => const AppException(
        'You do not have permission to perform this action.',
        statusCode: 403,
      );

  @override
  String toString() => message;
}
