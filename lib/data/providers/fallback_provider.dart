import '../../core/errors/exceptions.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/entities/prayer_times.dart';
import 'prayer_data_provider.dart';

/// Provider that wraps multiple providers with fallback logic
class FallbackProvider implements PrayerDataProvider {
  final List<PrayerDataProvider> _providers;
  final _logger = AppLogger();
  
  PrayerDataProvider? _activeProvider;
  int _activeProviderIndex = 0;

  FallbackProvider({required List<PrayerDataProvider> providers})
    : _providers = List.unmodifiable(providers) {
    if (providers.isEmpty) {
      throw ArgumentError('At least one provider is required');
    }
  }

  @override
  String get id => 'fallback_chain';

  @override
  String get name => 'Auto-Fallback Chain';

  @override
  String get description => 
    'Automatically falls back to next provider on failure. Chain: ' +
    _providers.map((p) => p.name).join(' → ');

  @override
  List<ConfigField> get configSchema => [];

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Initialize all providers with their respective configs
    for (int i = 0; i < _providers.length; i++) {
      final provider = _providers[i];
      final providerConfig = config[provider.id] as Map<String, dynamic>? ?? {};
      
      try {
        await provider.initialize(providerConfig);
        _logger.i('Initialized provider ${provider.name}');
      } catch (e) {
        _logger.w('Failed to initialize provider ${provider.name}: $e');
      }
    }
  }

  @override
  Future<List<Mosque>> searchMosques(String query, {GeoLocation? location}) async {
    return _executeWithFallback(
      (provider) => provider.searchMosques(query, location: location),
      'searchMosques',
    );
  }

  @override
  Future<List<Mosque>> getNearbyMosques(GeoLocation location, {double radiusKm = 10}) async {
    return _executeWithFallback(
      (provider) => provider.getNearbyMosques(location, radiusKm: radiusKm),
      'getNearbyMosques',
    );
  }

  @override
  Future<PrayerTimes> getPrayerTimes(String mosqueId, {DateTime? date}) async {
    return _executeWithFallback(
      (provider) => provider.getPrayerTimes(mosqueId, date: date),
      'getPrayerTimes',
    );
  }

  @override
  Future<Mosque> getMosqueDetails(String mosqueId) async {
    return _executeWithFallback(
      (provider) => provider.getMosqueDetails(mosqueId),
      'getMosqueDetails',
    );
  }

  @override
  Future<bool> testConnection() async {
    for (final provider in _providers) {
      try {
        final result = await provider.testConnection();
        if (result) {
          _activeProvider = provider;
          return true;
        }
      } catch (_) {
        // Continue to next provider
      }
    }
    return false;
  }

  /// Execute operation with fallback to next provider on failure
  Future<T> _executeWithFallback<T>(
    Future<T> Function(PrayerDataProvider provider) operation,
    String operationName,
  ) async {
    Exception? lastError;
    
    // Start from the last known working provider, or from the beginning
    final startIndex = _activeProviderIndex;
    
    for (int i = 0; i < _providers.length; i++) {
      final index = (startIndex + i) % _providers.length;
      final provider = _providers[index];
      
      try {
        _logger.d('Trying $operationName with ${provider.name}');
        final result = await operation(provider);
        
        // Success - remember this provider
        if (_activeProviderIndex != index) {
          _logger.i('Switched to provider ${provider.name}');
          _activeProviderIndex = index;
          _activeProvider = provider;
        }
        
        return result;
      } on NoConnectionException {
        // Don't retry on no connection - all providers will fail
        rethrow;
      } on Exception catch (e) {
        lastError = e;
        _logger.w(
          '$operationName failed with ${provider.name}',
          error: e,
        );
        // Continue to next provider
      }
    }

    // All providers failed
    throw AppException(
      message: 'All providers failed for $operationName',
      code: 'ALL_PROVIDERS_FAILED',
      originalError: lastError,
    );
  }

  /// Get the currently active provider
  PrayerDataProvider? get activeProvider => _activeProvider;

  /// Get provider health status
  Future<Map<String, bool>> getProviderHealth() async {
    final health = <String, bool>{};
    
    for (final provider in _providers) {
      try {
        health[provider.id] = await provider.testConnection();
      } catch (_) {
        health[provider.id] = false;
      }
    }
    
    return health;
  }

  @override
  void dispose() {
    for (final provider in _providers) {
      provider.dispose();
    }
  }
}

/// Builder for creating fallback provider chains
class FallbackProviderBuilder {
  final List<PrayerDataProvider> _providers = [];

  FallbackProviderBuilder add(PrayerDataProvider provider) {
    _providers.add(provider);
    return this;
  }

  FallbackProviderBuilder addIf(PrayerDataProvider provider, bool condition) {
    if (condition) {
      _providers.add(provider);
    }
    return this;
  }

  FallbackProvider build() {
    return FallbackProvider(providers: List.unmodifiable(_providers));
  }
}
