class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final Map<String, dynamic>? meta;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.meta,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: fromData != null && json['data'] != null
          ? fromData(json['data'])
          : null,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() =>
      'ApiResponse(success: $success, message: $message, data: $data)';
}
