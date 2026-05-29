import 'dart:convert';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../services/app_logger.dart';

class PrettyLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _printRequest(options);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      _printResponse(response);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      _printError(err);
    }
    handler.next(err);
  }

  // ── helpers ───────────────────────────────────────────

  void _printRequest(RequestOptions options) {
    final method = options.method.padRight(6);
    final uri = '${options.baseUrl}${options.path}';
    final details = {
      if (options.queryParameters.isNotEmpty)
        'Query': _encode(options.queryParameters),
      if (options.data != null) 'Body': _encode(options.data),
      'Token': options.headers['Authorization'] != null ? '✓ present' : '✗ none',
    };
    _box(header: '→ $method $uri', color: _cyan, entries: details);
    AppLogger.instance.network(
      '→ ${options.method} $uri',
      extra: details.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
    );
  }

  void _printResponse(Response response) {
    final code = response.statusCode ?? 0;
    final method = response.requestOptions.method.padRight(6);
    final uri =
        '${response.requestOptions.baseUrl}${response.requestOptions.path}';
    final color = code < 300 ? _green : _yellow;
    final details = {'Body': _encode(response.data)};
    _box(header: '← $code $method $uri', color: color, entries: details);
    AppLogger.instance.network(
      '← $code ${response.requestOptions.method} $uri',
      extra: _encode(response.data),
    );
  }

  void _printError(DioException err) {
    final code = err.response?.statusCode ?? 0;
    final method = err.requestOptions.method.padRight(6);
    final uri =
        '${err.requestOptions.baseUrl}${err.requestOptions.path}';
    final details = {
      'Message': err.message ?? err.type.name,
      if (err.response?.data != null) 'Body': _encode(err.response!.data),
      'Stack': err.stackTrace.toString().split('\n').take(5).join('\n'),
    };
    _box(header: '✗ $code $method $uri', color: _red, entries: details);
    AppLogger.instance.e(
      '✗ $code ${err.requestOptions.method} $uri',
      tag: 'Network',
      extra: details.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
    );
  }

  void _box({
    required String header,
    required String color,
    required Map<String, String> entries,
  }) {
    final lines = StringBuffer();
    lines.writeln('$color╔══ $header');
    for (final e in entries.entries) {
      final label = e.key.padRight(8);
      final value = e.value;
      if (value.contains('\n')) {
        lines.writeln('$color║ $label:');
        for (final line in value.split('\n')) {
          lines.writeln('$color║   $line');
        }
      } else {
        lines.writeln('$color║ $label: $value');
      }
    }
    lines.write('$color╚${'═' * 60}$_reset');
    dev.log(lines.toString(), name: 'Network');
  }

  String _encode(dynamic data) {
    if (data == null) return 'null';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  static const _reset = '\x1B[0m';
  static const _green = '\x1B[32m';
  static const _cyan = '\x1B[36m';
  static const _yellow = '\x1B[33m';
  static const _red = '\x1B[31m';
}
