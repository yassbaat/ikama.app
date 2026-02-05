import '../../domain/entities/mosque.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/entities/geo_location.dart';

/// Exception thrown when provider operation fails
class ProviderException implements Exception {
  final String message;
  final int? statusCode;
  final String? providerId;

  const ProviderException({
    required this.message,
    this.statusCode,
    this.providerId,
  });

  @override
  String toString() => 'ProviderException[$providerId]: $message';
}

/// Configuration schema for provider settings
class ConfigField {
  final String key;
  final String label;
  final ConfigFieldType type;
  final bool required;
  final String? description;
  final String? defaultValue;
  final List<String>? options;

  const ConfigField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.description,
    this.defaultValue,
    this.options,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    'required': required,
    'description': description,
    'defaultValue': defaultValue,
    'options': options,
  };
}

enum ConfigFieldType {
  string,
  password,
  number,
  boolean,
  url,
  select,
}

/// Abstract interface for all prayer data providers
/// Implementations: Provider A (Official API), Provider B (Community Wrapper), Provider C (Scraping)
abstract class PrayerDataProvider {
  /// Provider unique identifier
  String get id;
  
  /// Provider display name
  String get name;
  
  /// Provider description
  String get description;
  
  /// Configuration schema for settings UI
  List<ConfigField> get configSchema;
  
  /// Initialize provider with configuration
  Future<void> initialize(Map<String, dynamic> config);
  
  /// Search mosques by query string
  Future<List<Mosque>> searchMosques(String query, {GeoLocation? location});
  
  /// Get mosques near a location
  Future<List<Mosque>> getNearbyMosques(GeoLocation location, {double radiusKm = 10});
  
  /// Fetch prayer times for a specific mosque
  Future<PrayerTimes> getPrayerTimes(String mosqueId, {DateTime? date});
  
  /// Test connectivity with current configuration
  Future<bool> testConnection();
  
  /// Get mosque details
  Future<Mosque> getMosqueDetails(String mosqueId);
  
  /// Dispose resources
  void dispose();
}

/// Factory for creating providers
class PrayerDataProviderFactory {
  static final Map<String, PrayerDataProvider Function()> _providers = {};

  static void register(String id, PrayerDataProvider Function() creator) {
    _providers[id] = creator;
  }

  static PrayerDataProvider? create(String id) {
    final creator = _providers[id];
    return creator?.call();
  }

  static List<String> get availableProviders => _providers.keys.toList();
}
