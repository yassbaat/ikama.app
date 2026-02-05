import 'package:dio/dio.dart';
import '../errors/exceptions.dart';
import 'retry_handler.dart';

/// Configuration for HTTP client
class HttpClientConfig {
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Map<String, String> headers;
  final String? baseUrl;
  final List<Interceptor> interceptors;
  final RetryConfig retryConfig;

  const HttpClientConfig({
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.headers = const {},
    this.baseUrl,
    this.interceptors = const [],
    this.retryConfig = RetryConfig.defaultConfig,
  });
}

/// Robust HTTP client with retry logic and error handling
class RobustHttpClient {
  late final Dio _dio;
  final RetryHandler _retryHandler;
  final HttpClientConfig config;

  RobustHttpClient({
    HttpClientConfig? config,
    Dio? dio,
  }) : config = config ?? const HttpClientConfig(),
       _retryHandler = RetryHandler(config: config?.retryConfig ?? RetryConfig.defaultConfig) {
    _dio = dio ?? _createDio();
  }

  Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: config.baseUrl ?? '',
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.sendTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ...config.headers,
      },
    ));

    // Add logging interceptor in debug mode
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
    ));

    // Add custom interceptors
    for (final interceptor in config.interceptors) {
      dio.interceptors.add(interceptor);
    }

    return dio;
  }

  /// GET request with retry
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    RetryConfig? retryConfig,
  }) async {
    return _executeWithRetry(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
      'GET $path',
      retryConfig,
    );
  }

  /// POST request with retry
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    RetryConfig? retryConfig,
  }) async {
    return _executeWithRetry(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      'POST $path',
      retryConfig,
    );
  }

  /// PUT request with retry
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    RetryConfig? retryConfig,
  }) async {
    return _executeWithRetry(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      ),
      'PUT $path',
      retryConfig,
    );
  }

  /// DELETE request with retry
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    RetryConfig? retryConfig,
  }) async {
    return _executeWithRetry(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      'DELETE $path',
      retryConfig,
    );
  }

  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName,
    RetryConfig? retryConfig,
  ) async {
    try {
      final handler = retryConfig != null 
        ? RetryHandler(config: retryConfig) 
        : _retryHandler;
      
      return await handler.execute(
        operation,
        operationName: operationName,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppException(
        message: 'Unexpected error: $e',
        originalError: e,
      );
    }
  }

  AppException _mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(
          message: 'Request timed out. Please try again.',
          originalError: error,
        );
        
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (error.error.toString().contains('SocketException') ||
            error.error.toString().contains('Connection refused')) {
          return NoConnectionException(
            originalError: error,
          );
        }
        return NetworkException(
          message: 'Network error: ${error.message}',
          originalError: error,
        );
        
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _extractErrorMessage(error.response?.data) ?? 
          'Server returned error ${statusCode}';
        
        if (statusCode == 404) {
          return NotFoundException(
            message: 'Resource not found',
            originalError: error,
          );
        }
        
        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message: message,
            statusCode: statusCode,
            originalError: error,
          );
        }
        
        if (statusCode == 400 || statusCode == 422) {
          return ValidationException(
            message: message,
            originalError: error,
          );
        }
        
        return NetworkException(
          message: message,
          statusCode: statusCode,
          originalError: error,
        );
        
      case DioExceptionType.cancel:
        return AppException(
          message: 'Request was cancelled',
          code: 'CANCELLED',
          originalError: error,
        );
        
      case DioExceptionType.badCertificate:
        return NetworkException(
          message: 'SSL certificate error',
          originalError: error,
        );
        
      default:
        return NetworkException(
          message: error.message ?? 'Unknown network error',
          originalError: error,
        );
    }
  }

  String? _extractErrorMessage(dynamic data) {
    if (data == null) return null;
    
    if (data is Map) {
      // Try common error message fields
      for (final key in ['message', 'error', 'errorMessage', 'detail', 'details']) {
        if (data[key] != null) {
          return data[key].toString();
        }
      }
      
      // Try nested error object
      if (data['error'] is Map) {
        return _extractErrorMessage(data['error']);
      }
    }
    
    return data.toString();
  }

  void dispose() {
    _dio.close();
  }
}

/// Interceptor for adding authentication headers
class AuthInterceptor extends Interceptor {
  final Future<String?> Function() getToken;

  AuthInterceptor({required this.getToken});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Interceptor for rate limiting
class RateLimitInterceptor extends Interceptor {
  final Duration minInterval;
  DateTime? _lastRequest;

  RateLimitInterceptor({this.minInterval = const Duration(milliseconds: 100)});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_lastRequest != null) {
      final elapsed = DateTime.now().difference(_lastRequest!);
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
    }
    _lastRequest = DateTime.now();
    handler.next(options);
  }
}
