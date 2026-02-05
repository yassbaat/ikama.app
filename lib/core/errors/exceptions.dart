/// Base exception for all app-specific errors
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException[$code]: $message';
}

/// Network-related exceptions
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException({
    required super.message,
    this.statusCode,
    super.originalError,
  }) : super(code: 'NETWORK_ERROR');
}

/// Server-side errors
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    required super.message,
    this.statusCode,
    super.originalError,
  }) : super(code: 'SERVER_ERROR');
}

/// Cache/database errors
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.originalError,
  }) : super(code: 'DATABASE_ERROR');
}

/// Not found errors
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.originalError,
  }) : super(code: 'NOT_FOUND');
}

/// Validation errors
class ValidationException extends AppException {
  final Map<String, String>? errors;

  const ValidationException({
    required super.message,
    this.errors,
    super.originalError,
  }) : super(code: 'VALIDATION_ERROR');
}

/// Timeout errors
class TimeoutException extends AppException {
  const TimeoutException({
    required super.message,
    super.originalError,
  }) : super(code: 'TIMEOUT');
}

/// No internet connection
class NoConnectionException extends AppException {
  const NoConnectionException({
    super.message = 'No internet connection',
    super.originalError,
  }) : super(code: 'NO_CONNECTION');
}
