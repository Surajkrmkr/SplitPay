import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

enum LogLevel { verbose, debug, info, warning, error, network }

class LogEntry {
  final int id;
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? extra;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.extra,
  });
}

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  final _controller = StreamController<List<LogEntry>>.broadcast();
  final _entries = <LogEntry>[];
  int _idCounter = 0;

  static const _maxEntries = 500;

  Stream<List<LogEntry>> get stream => _controller.stream;
  List<LogEntry> get entries => List.unmodifiable(_entries);

  void v(String message, {String tag = 'Verbose', String? extra}) =>
      _add(LogLevel.verbose, tag, message, extra);

  void d(String message, {String tag = 'Debug', String? extra}) =>
      _add(LogLevel.debug, tag, message, extra);

  void i(String message, {String tag = 'Info', String? extra}) =>
      _add(LogLevel.info, tag, message, extra);

  void w(String message, {String tag = 'Warning', String? extra}) =>
      _add(LogLevel.warning, tag, message, extra);

  void e(String message, {String tag = 'Error', String? extra}) =>
      _add(LogLevel.error, tag, message, extra);

  void network(String message, {String tag = 'Network', String? extra}) =>
      _add(LogLevel.network, tag, message, extra);

  void clear() {
    _entries.clear();
    if (!_controller.isClosed) _controller.add(const []);
  }

  void _add(LogLevel level, String tag, String message, String? extra) {
    final entry = LogEntry(
      id: _idCounter++,
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      extra: extra,
    );
    if (_entries.length >= _maxEntries) _entries.removeAt(0);
    _entries.add(entry);
    if (!_controller.isClosed) _controller.add(List.unmodifiable(_entries));
    if (kDebugMode) {
      dev.log(message, name: '${level.name.toUpperCase()}/$tag');
    }
  }
}
