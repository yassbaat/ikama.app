import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../errors/exceptions.dart';

/// Configuration for retry behavior
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool useJitter;
  final List<int> retryableStatusCodes;
  final List<Type> retryableExceptions;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
    this.retryableStatusCodes = const [408, 429, 500, 502, 503, 504],
    this.retryableExceptions = const [TimeoutException, NetworkException, ServerException],
  });

  static const RetryConfig defaultConfig = RetryConfig();
  
  static const RetryConfig aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 200),
    maxDelay: const Duration(seconds: 5),
  );

  static const RetryConfig conservative = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: const Duration(seconds: 30),
    backoffMultiplier: 3.0,
  );
}

/// Result of a retry operation
class RetryResult<T> {
  final T? value;
  final bool success;
  final int attempts;
  final Duration totalDuration;
  final Exception? lastError;

  const RetryResult({
    this.value,
    required this.success,
    required this.attempts,
    required this.totalDuration,
    this.lastError,
  });
}

/// Handles retry logic with exponential backoff
class RetryHandler {
  final RetryConfig config;
  final Connectivity _connectivity;

  RetryHandler({
    this.config = RetryConfig.defaultConfig,
  }) : _connectivity = Connectivity();

  /// Execute an operation with retry logic
  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? operationName,
    Future<void> Function(int attempt, Exception error)? onRetry,
    bool Function(Exception error)? shouldRetry,
  }) async {
    final stopwatch = Stopwatch()..start();
    int attempt = 0;
    Exception? lastError;

    while (attempt < config.maxAttempts) {
      attempt++;
      
      try {
        // Check connectivity before attempting
        final connectivityResult = await _connectivity.checkConnectivity();
        if (connectivityResult == ConnectivityResult.none && attempt > 1) {
          throw const NoConnectionException();
        }

        final result = await operation();
        stopwatch.stop();
        
        return result;
      } on Exception catch (e) {
        lastError = e;
        
        // Check if we should retry this error
        if (attempt >= config.maxAttempts) {
          break;
        }
        
        if (shouldRetry != null && !shouldRetry(e)) {
          break;
        }
        
        if (!_isRetryableError(e)) {
          break;
        }

        // Calculate delay with exponential backoff
        final delay = _calculateDelay(attempt);
        
        // Call retry callback if provided
        if (onRetry != null) {
          await onRetry(attempt, e);
        }
        
        // Wait before retrying
        await Future.delayed(delay);
      }
    }

    stopwatch.stop();
    
    // All retries exhausted
    throw lastError ?? AppException(
      message: 'Operation failed after $attempt attempts',
      code: 'MAX_RETRIES_EXCEEDED',
    );
  }

  /// Execute with detailed result information
  Future<RetryResult<T>> executeWithResult<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    final stopwatch = Stopwatch()..start();
    int attempt = 0;
    Exception? lastError;

    while (attempt < config.maxAttempts) {
      attempt++;
      
      try {
        final connectivityResult = await _connectivity.checkConnectivity();
        if (connectivityResult == ConnectivityResult.none && attempt > 1) {
          throw const NoConnectionException();
        }

        final result = await operation();
        stopwatch.stop();
        
        return RetryResult<T>(
          value: result,
          success: true,
          attempts: attempt,
          totalDuration: stopwatch.elapsed,
        );
      } on Exception catch (e) {
        lastError = e;
        
        if (attempt >= config.maxAttempts || !_isRetryableError(e)) {
          break;
        }

        await Future.delayed(_calculateDelay(attempt));
      }
    }

    stopwatch.stop();
    
    return RetryResult<T>(
      success: false,
      attempts: attempt,
      totalDuration: stopwatch.elapsed,
      lastError: lastError,
    );
  }

  bool _isRetryableError(Exception error) {
    // Check if error type is retryable
    for (final type in config.retryableExceptions) {
      if (error.runtimeType == type) return true;
    }

    // Check specific error types
    if (error is NetworkException) {
      return config.retryableStatusCodes.contains(error.statusCode);
    }
    
    if (error is ServerException) {
      return config.retryableStatusCodes.contains(error.statusCode);
    }

    return false;
  }

  Duration _calculateDelay(int attempt) {
    // Base exponential backoff
    var delay = config.initialDelay * pow(config.backoffMultiplier, attempt - 1);
    
    // Clamp to max delay
    if (delay > config.maxDelay) {
      delay = config.maxDelay;
    }
    
    // Add jitter to prevent thundering herd
    if (config.useJitter) {
      final jitter = Random().nextDouble() * 0.3 + 0.85; // 0.85 - 1.15
      delay = Duration(milliseconds: (delay.inMilliseconds * jitter).round());
    }
    
    return delay;
  }
}

/// Mixin for classes that need retry functionality
mixin RetryableOperations {
  RetryHandler get retryHandler;

  Future<T> withRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
    Future<void> Function(int attempt, Exception error)? onRetry,
  }) async {
    return retryHandler.execute(
      operation,
      operationName: operationName,
      onRetry: onRetry,
    );
  }
}
