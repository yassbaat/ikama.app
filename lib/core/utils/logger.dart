import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as external_logger;

/// Log level enum
enum LogLevel {
  verbose(0),
  debug(1),
  info(2),
  warning(3),
  error(4),
  fatal(5);

  final int value;
  const LogLevel(this.value);

  bool operator >=(LogLevel other) => value >= other.value;
}

/// Log entry model
class LogEntry {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;
  final dynamic data;
  final StackTrace? stackTrace;
  final String? errorCode;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.data,
    this.stackTrace,
    this.errorCode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    'tag': tag,
    'data': data?.toString(),
    'errorCode': errorCode,
  };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.name.toUpperCase()}] ');
    if (tag != null) buffer.write('[$tag] ');
    buffer.write(message);
    if (errorCode != null) buffer.write(' (Code: $errorCode)');
    return buffer.toString();
  }
}

/// Configuration for the logger
class LoggerConfig {
  final LogLevel minLevel;
  final int maxBufferSize;
  final bool printToConsole;
  final bool includeStackTrace;
  final Duration? autoFlushInterval;
  final Future<void> Function(List<LogEntry>)? onBatchFlush;

  const LoggerConfig({
    this.minLevel = LogLevel.debug,
    this.maxBufferSize = 100,
    this.printToConsole = true,
    this.includeStackTrace = true,
    this.autoFlushInterval,
    this.onBatchFlush,
  });

  static const LoggerConfig production = LoggerConfig(
    minLevel: LogLevel.info,
    maxBufferSize: 500,
    printToConsole: false,
    includeStackTrace: false,
    autoFlushInterval: Duration(minutes: 5),
  );

  static const LoggerConfig development = LoggerConfig(
    minLevel: LogLevel.verbose,
    maxBufferSize: 100,
    printToConsole: true,
    includeStackTrace: true,
  );
}

/// Centralized logging service
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  LoggerConfig _config = LoggerConfig.development;
  final List<LogEntry> _buffer = [];
  final _bufferLock = Object();
  Timer? _autoFlushTimer;
  external_logger.Logger? _externalLogger;

  void initialize({LoggerConfig? config}) {
    _config = config ?? LoggerConfig.development;
    
    _externalLogger = external_logger.Logger(
      printer: external_logger.PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
      ),
    );

    if (_config.autoFlushInterval != null) {
      _autoFlushTimer = Timer.periodic(
        _config.autoFlushInterval!,
        (_) => flush(),
      );
    }
  }

  /// Log a verbose message
  void v(String message, {String? tag, dynamic data}) {
    _log(LogLevel.verbose, message, tag: tag, data: data);
  }

  /// Log a debug message
  void d(String message, {String? tag, dynamic data}) {
    _log(LogLevel.debug, message, tag: tag, data: data);
  }

  /// Log an info message
  void i(String message, {String? tag, dynamic data}) {
    _log(LogLevel.info, message, tag: tag, data: data);
  }

  /// Log a warning
  void w(String message, {String? tag, dynamic data, String? warningCode}) {
    _log(LogLevel.warning, message, tag: tag, data: data, errorCode: warningCode);
  }

  /// Log an error
  void e(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
    String? errorCode,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      data: error,
      stackTrace: stackTrace,
      errorCode: errorCode,
    );
  }

  /// Log a fatal error
  void f(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
    String? errorCode,
  }) {
    _log(
      LogLevel.fatal,
      message,
      tag: tag,
      data: error,
      stackTrace: stackTrace,
      errorCode: errorCode,
    );
    // Fatal errors should be flushed immediately
    flush();
  }

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    dynamic data,
    StackTrace? stackTrace,
    String? errorCode,
  }) {
    if (level < _config.minLevel) return;

    final entry = LogEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_buffer.length}',
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
      data: data,
      stackTrace: stackTrace,
      errorCode: errorCode,
    );

    // Add to buffer
    synchronized(_bufferLock, () {
      _buffer.add(entry);
      
      // Flush if buffer is full
      if (_buffer.length >= _config.maxBufferSize) {
        flush();
      }
    });

    // Print to console in debug mode
    if (_config.printToConsole && kDebugMode) {
      _printToConsole(entry);
    }
  }

  void _printToConsole(LogEntry entry) {
    final externalLevel = switch (entry.level) {
      LogLevel.verbose => external_logger.Level.trace,
      LogLevel.debug => external_logger.Level.debug,
      LogLevel.info => external_logger.Level.info,
      LogLevel.warning => external_logger.Level.warning,
      LogLevel.error => external_logger.Level.error,
      LogLevel.fatal => external_logger.Level.fatal,
    };

    _externalLogger?.log(
      externalLevel,
      entry.message,
      error: entry.data,
      stackTrace: entry.stackTrace,
    );
  }

  /// Flush buffered logs
  Future<void> flush() async {
    List<LogEntry> logsToFlush;
    
    synchronized(_bufferLock, () {
      if (_buffer.isEmpty) return;
      logsToFlush = List.unmodifiable(_buffer);
      _buffer.clear();
    });

    if (logsToFlush.isEmpty) return;

    try {
      await _config.onBatchFlush?.call(logsToFlush);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to flush logs: $e');
      }
    }
  }

  /// Get recent logs
  List<LogEntry> getRecentLogs({int count = 50, LogLevel? minLevel}) {
    return synchronized(_bufferLock, () {
      var logs = _buffer.toList().reversed.take(count).toList();
      if (minLevel != null) {
        logs = logs.where((l) => l.level >= minLevel).toList();
      }
      return logs;
    });
  }

  /// Export logs as JSON
  Future<String> exportLogs() async {
    final logs = getRecentLogs(count: _config.maxBufferSize);
    final jsonList = logs.map((e) => e.toJson()).toList();
    return jsonList.toString(); // Simplified - use jsonEncode in production
  }

  /// Clear all buffered logs
  void clear() {
    synchronized(_bufferLock, () {
      _buffer.clear();
    });
  }

  void dispose() {
    _autoFlushTimer?.cancel();
    flush();
  }
}

/// Simple synchronization helper
T synchronized<T>(Object lock, T Function() action) {
  // In a real implementation, this would use proper locking
  return action();
}

/// Mixin for classes that need logging
mixin Loggable {
  String get loggerTag => runtimeType.toString();
  
  AppLogger get logger => AppLogger();

  void logV(String message, {dynamic data}) => 
    logger.v(message, tag: loggerTag, data: data);
  
  void logD(String message, {dynamic data}) => 
    logger.d(message, tag: loggerTag, data: data);
  
  void logI(String message, {dynamic data}) => 
    logger.i(message, tag: loggerTag, data: data);
  
  void logW(String message, {dynamic data, String? warningCode}) => 
    logger.w(message, tag: loggerTag, data: data, warningCode: warningCode);
  
  void logE(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? errorCode,
  }) => logger.e(
    message,
    tag: loggerTag,
    error: error,
    stackTrace: stackTrace,
    errorCode: errorCode,
  );
}
