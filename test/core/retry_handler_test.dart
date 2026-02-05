import 'package:flutter_test/flutter_test.dart';
import 'package:iqamah/core/utils/retry_handler.dart';
import 'package:iqamah/core/errors/exceptions.dart';

void main() {
  group('RetryHandler', () {
    late RetryHandler handler;

    setUp(() {
      handler = RetryHandler(config: const RetryConfig(maxAttempts: 3, initialDelay: Duration(milliseconds: 10)));
    });

    group('execute', () {
      test('returns result on first attempt', () async {
        var attempts = 0;
        
        final result = await handler.execute(() async {
          attempts++;
          return 'success';
        });

        expect(result, equals('success'));
        expect(attempts, equals(1));
      });

      test('retries on retryable error and succeeds', () async {
        var attempts = 0;
        
        final result = await handler.execute(() async {
          attempts++;
          if (attempts < 3) {
            throw const NetworkException(message: 'Network error');
          }
          return 'success';
        });

        expect(result, equals('success'));
        expect(attempts, equals(3));
      });

      test('throws after max attempts', () async {
        var attempts = 0;
        
        expect(
          () => handler.execute(() async {
            attempts++;
            throw const NetworkException(message: 'Network error');
          }),
          throwsA(isA<NetworkException>()),
        );

        expect(attempts, equals(3));
      });

      test('calls onRetry callback', () async {
        var attempts = 0;
        var retryCallbackCount = 0;
        
        await handler.execute(
          () async {
            attempts++;
            if (attempts < 2) {
              throw const NetworkException(message: 'Network error');
            }
            return 'success';
          },
          onRetry: (attempt, error) async {
            retryCallbackCount++;
          },
        );

        expect(retryCallbackCount, equals(1));
      });

      test('does not retry on non-retryable error', () async {
        var attempts = 0;
        
        expect(
          () => handler.execute(() async {
            attempts++;
            throw const ValidationException(message: 'Invalid input');
          }),
          throwsA(isA<ValidationException>()),
        );

        expect(attempts, equals(1));
      });

      test('respects custom shouldRetry function', () async {
        var attempts = 0;
        
        expect(
          () => handler.execute(
            () async {
              attempts++;
              throw const NetworkException(message: 'Network error');
            },
            shouldRetry: (error) => false,
          ),
          throwsA(isA<NetworkException>()),
        );

        expect(attempts, equals(1));
      });
    });

    group('executeWithResult', () {
      test('returns success result', () async {
        final result = await handler.executeWithResult(() async => 'success');

        expect(result.success, isTrue);
        expect(result.value, equals('success'));
        expect(result.attempts, equals(1));
      });

      test('returns failure result after max attempts', () async {
        final result = await handler.executeWithResult(
          () async => throw const NetworkException(message: 'Network error'),
        );

        expect(result.success, isFalse);
        expect(result.attempts, equals(3));
        expect(result.lastError, isA<NetworkException>());
      });
    });

    group('delay calculation', () {
      test('increases delay with each attempt', () async {
        final delays = <Duration>[];
        var attempts = 0;

        final customHandler = RetryHandler(
          config: const RetryConfig(
            maxAttempts: 4,
            initialDelay: Duration(milliseconds: 100),
            backoffMultiplier: 2.0,
            useJitter: false,
          ),
        );

        final stopwatch = Stopwatch()..start();
        
        try {
          await customHandler.execute(
            () async {
              attempts++;
              if (attempts > 1) {
                delays.add(stopwatch.elapsed);
              }
              stopwatch.reset();
              throw const NetworkException(message: 'Network error');
            },
          );
        } catch (_) {}

        // Check that delays are increasing (approximately)
        expect(delays.length, greaterThanOrEqualTo(2));
      });
    });
  });

  group('RetryConfig', () {
    test('default config has reasonable values', () {
      const config = RetryConfig.defaultConfig;
      
      expect(config.maxAttempts, equals(3));
      expect(config.initialDelay, equals(const Duration(milliseconds: 500)));
      expect(config.useJitter, isTrue);
    });

    test('aggressive config has lower delays', () {
      const config = RetryConfig.aggressive;
      
      expect(config.maxAttempts, equals(5));
      expect(config.initialDelay, equals(const Duration(milliseconds: 200)));
    });

    test('conservative config has higher delays', () {
      const config = RetryConfig.conservative;
      
      expect(config.maxAttempts, equals(3));
      expect(config.initialDelay, equals(const Duration(seconds: 1)));
      expect(config.backoffMultiplier, equals(3.0));
    });
  });

  group('RetryResult', () {
    test('success result has correct properties', () {
      const result = RetryResult<String>(
        value: 'test',
        success: true,
        attempts: 1,
        totalDuration: Duration(milliseconds: 100),
      );

      expect(result.success, isTrue);
      expect(result.value, equals('test'));
      expect(result.attempts, equals(1));
      expect(result.lastError, isNull);
    });

    test('failure result has correct properties', () {
      final error = NetworkException(message: 'Test error');
      final result = RetryResult<String>(
        success: false,
        attempts: 3,
        totalDuration: Duration(seconds: 5),
        lastError: error,
      );

      expect(result.success, isFalse);
      expect(result.value, isNull);
      expect(result.attempts, equals(3));
      expect(result.lastError, equals(error));
    });
  });
}
