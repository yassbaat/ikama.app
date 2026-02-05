import '../../domain/entities/geo_location.dart';

/// Validation result
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> errors;

  const ValidationResult.valid()
    : isValid = true,
      errorMessage = null,
      errors = const [];

  const ValidationResult.invalid(this.errorMessage)
    : isValid = false,
      errors = const [];

  const ValidationResult.multipleErrors(this.errors)
    : isValid = false,
      errorMessage = errors.isNotEmpty ? errors.first : 'Validation failed';

  static ValidationResult merge(List<ValidationResult> results) {
    final allErrors = results
      .where((r) => !r.isValid)
      .expand((r) => r.errors.isNotEmpty ? r.errors : [if (r.errorMessage != null) r.errorMessage!])
      .toList();
    
    if (allErrors.isEmpty) {
      return const ValidationResult.valid();
    }
    return ValidationResult.multipleErrors(allErrors);
  }
}

/// Input validation utilities
class Validators {
  Validators._();

  /// Validate mosque ID
  static ValidationResult mosqueId(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.invalid('Mosque ID is required');
    }
    if (value.length < 3) {
      return const ValidationResult.invalid('Mosque ID must be at least 3 characters');
    }
    return const ValidationResult.valid();
  }

  /// Validate mosque name
  static ValidationResult mosqueName(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.invalid('Mosque name is required');
    }
    if (value.length < 2) {
      return const ValidationResult.invalid('Mosque name must be at least 2 characters');
    }
    if (value.length > 200) {
      return const ValidationResult.invalid('Mosque name is too long');
    }
    return const ValidationResult.valid();
  }

  /// Validate search query
  static ValidationResult searchQuery(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.invalid('Search query is required');
    }
    if (value.length < 2) {
      return const ValidationResult.invalid('Search query must be at least 2 characters');
    }
    if (value.length > 100) {
      return const ValidationResult.invalid('Search query is too long');
    }
    // Sanitize - remove potentially dangerous characters
    final sanitized = _sanitizeSearchQuery(value);
    if (sanitized != value) {
      return const ValidationResult.invalid('Search query contains invalid characters');
    }
    return const ValidationResult.valid();
  }

  /// Validate URL
  static ValidationResult url(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.invalid('URL is required');
    }
    
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return const ValidationResult.invalid('Invalid URL format');
    }
    
    if (!uri.isScheme('http') && !uri.isScheme('https')) {
      return const ValidationResult.invalid('URL must use HTTP or HTTPS');
    }
    
    if (uri.host.isEmpty) {
      return const ValidationResult.invalid('URL must have a valid host');
    }
    
    return const ValidationResult.valid();
  }

  /// Validate API key/token
  static ValidationResult apiToken(String? value, {bool required = true}) {
    if (!required && (value == null || value.isEmpty)) {
      return const ValidationResult.valid();
    }
    
    if (value == null || value.isEmpty) {
      return const ValidationResult.invalid('API token is required');
    }
    
    if (value.length < 8) {
      return const ValidationResult.invalid('API token seems too short');
    }
    
    return const ValidationResult.valid();
  }

  /// Validate geographic coordinates
  static ValidationResult coordinates(double? latitude, double? longitude) {
    final errors = <String>[];
    
    if (latitude == null) {
      errors.add('Latitude is required');
    } else if (latitude < -90 || latitude > 90) {
      errors.add('Latitude must be between -90 and 90');
    }
    
    if (longitude == null) {
      errors.add('Longitude is required');
    } else if (longitude < -180 || longitude > 180) {
      errors.add('Longitude must be between -180 and 180');
    }
    
    if (errors.isEmpty) {
      return const ValidationResult.valid();
    }
    return ValidationResult.multipleErrors(errors);
  }

  /// Validate GeoLocation
  static ValidationResult geoLocation(GeoLocation? location) {
    if (location == null) {
      return const ValidationResult.invalid('Location is required');
    }
    return coordinates(location.latitude, location.longitude);
  }

  /// Validate travel time
  static ValidationResult travelTime(int? seconds) {
    if (seconds == null) {
      return const ValidationResult.invalid('Travel time is required');
    }
    if (seconds < 0) {
      return const ValidationResult.invalid('Travel time cannot be negative');
    }
    if (seconds > 86400) { // 24 hours
      return const ValidationResult.invalid('Travel time seems too long (max 24 hours)');
    }
    return const ValidationResult.valid();
  }

  /// Validate rakah duration
  static ValidationResult rakahDuration(int? seconds) {
    if (seconds == null) {
      return const ValidationResult.invalid('Duration is required');
    }
    if (seconds < 30) {
      return const ValidationResult.invalid('Duration seems too short (min 30 seconds)');
    }
    if (seconds > 600) { // 10 minutes
      return const ValidationResult.invalid('Duration seems too long (max 10 minutes)');
    }
    return const ValidationResult.valid();
  }

  /// Validate date is not in the far past or future
  static ValidationResult reasonableDate(DateTime? date) {
    if (date == null) {
      return const ValidationResult.invalid('Date is required');
    }
    
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays < -365) {
      return const ValidationResult.invalid('Date is too far in the past');
    }
    if (difference.inDays > 365) {
      return const ValidationResult.invalid('Date is too far in the future');
    }
    
    return const ValidationResult.valid();
  }

  /// Validate email (for user accounts if needed)
  static ValidationResult email(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.invalid('Email is required');
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return const ValidationResult.invalid('Invalid email format');
    }
    
    return const ValidationResult.valid();
  }

  /// Sanitize search query
  static String _sanitizeSearchQuery(String query) {
    // Remove SQL injection attempts and special characters
    return query
      .replaceAll(RegExp(r'[<>{})\[\];]'), '')
      .trim();
  }
}

/// Sanitizer utilities
class Sanitizers {
  Sanitizers._();

  /// Sanitize a string for display
  static String string(String? input, {int maxLength = 500}) {
    if (input == null) return '';
    
    return input
      .trim()
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // Remove control chars
      .substring(0, input.length > maxLength ? maxLength : input.length);
  }

  /// Sanitize a URL
  static String? url(String? input) {
    if (input == null) return null;
    
    final sanitized = input.trim();
    final result = Validators.url(sanitized);
    
    return result.isValid ? sanitized : null;
  }

  /// Coerce value to double within range
  static double? doubleInRange(dynamic value, double min, double max) {
    double? result;
    
    if (value is num) {
      result = value.toDouble();
    } else if (value is String) {
      result = double.tryParse(value);
    }
    
    if (result == null) return null;
    if (result < min) return min;
    if (result > max) return max;
    
    return result;
  }

  /// Coerce value to int within range
  static int? intInRange(dynamic value, int min, int max) {
    int? result;
    
    if (value is num) {
      result = value.toInt();
    } else if (value is String) {
      result = int.tryParse(value);
    }
    
    if (result == null) return null;
    if (result < min) return min;
    if (result > max) return max;
    
    return result;
  }
}
