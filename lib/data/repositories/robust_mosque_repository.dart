import '../../core/errors/exceptions.dart';
import '../../core/utils/connectivity_manager.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/retry_handler.dart';
import '../../domain/entities/geo_location.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/entities/prayer_times.dart';
import '../local/database_helper.dart';
import '../providers/prayer_data_provider.dart';

/// Enhanced repository with connectivity awareness, retry logic, and comprehensive error handling
class RobustMosqueRepository {
  final PrayerDataProvider _provider;
  final DatabaseHelper _database;
  final ConnectivityManager _connectivity;
  final RetryHandler _retryHandler;
  final AppLogger _logger;

  RobustMosqueRepository({
    required PrayerDataProvider provider,
    DatabaseHelper? database,
    ConnectivityManager? connectivity,
    RetryHandler? retryHandler,
    AppLogger? logger,
  })  : _provider = provider,
        _database = database ?? DatabaseHelper.instance,
        _connectivity = connectivity ?? ConnectivityManager(),
        _retryHandler = retryHandler ?? RetryHandler(),
        _logger = logger ?? AppLogger();

  /// Search mosques with fallback to cache
  Future<List<Mosque>> searchMosques(
    String query, {
    GeoLocation? location,
    bool useCacheOnError = true,
  }) async {
    _logger.d('Searching mosques', data: {'query': query, 'hasLocation': location != null});

    try {
      final results = await _retryHandler.execute(
        () async {
          await _connectivity.ensureConnected();
          return await _provider.searchMosques(query, location: location);
        },
        operationName: 'searchMosques',
      );

      // Cache results asynchronously
      _cacheMosquesAsync(results);

      _logger.i('Found ${results.length} mosques');
      return results;
    } on NoConnectionException {
      _logger.w('No connection, returning cached results');
      if (useCacheOnError) {
        return _getCachedMosquesMatching(query);
      }
      rethrow;
    } on Exception catch (e) {
      _logger.e('Search failed', error: e);
      
      if (useCacheOnError) {
        return _getCachedMosquesMatching(query);
      }
      
      throw RepositoryException(
        'Failed to search mosques: ${_getUserFriendlyError(e)}',
        originalError: e,
      );
    }
  }

  /// Get nearby mosques with fallback to cached favorites
  Future<List<Mosque>> getNearbyMosques(
    GeoLocation location, {
    double radiusKm = 10,
    bool useCacheOnError = true,
  }) async {
    _logger.d('Getting nearby mosques', data: {'lat': location.latitude, 'lng': location.longitude});

    try {
      final results = await _retryHandler.execute(
        () async {
          await _connectivity.ensureConnected();
          return await _provider.getNearbyMosques(location, radiusKm: radiusKm);
        },
        operationName: 'getNearbyMosques',
      );

      _cacheMosquesAsync(results);
      return results;
    } on NoConnectionException {
      if (useCacheOnError) {
        return _getCachedNearbyMosques(location);
      }
      rethrow;
    } on Exception catch (e) {
      _logger.e('Get nearby failed', error: e);
      
      if (useCacheOnError) {
        return _getCachedNearbyMosques(location);
      }
      
      throw RepositoryException(
        'Failed to get nearby mosques: ${_getUserFriendlyError(e)}',
        originalError: e,
      );
    }
  }

  /// Get prayer times with intelligent caching
  Future<PrayerTimes> getPrayerTimes(
    String mosqueId, {
    DateTime? date,
    bool forceRefresh = false,
    Duration maxCacheAge = const Duration(hours: 1),
  }) async {
    final targetDate = date ?? DateTime.now();
    final cacheKey = '${mosqueId}_${targetDate.toIso8601String()}';

    _logger.d('Getting prayer times', data: {
      'mosqueId': mosqueId,
      'date': targetDate,
      'forceRefresh': forceRefresh,
    });

    // Check cache first unless force refresh
    if (!forceRefresh) {
      try {
        final cached = await _database.getCachedPrayerTimes(mosqueId, targetDate);
        if (cached != null && cached.cachedAt != null) {
          final age = DateTime.now().difference(cached.cachedAt!);
          
          if (age < maxCacheAge) {
            _logger.d('Returning fresh cached data', data: {'age': age.inMinutes});
            return cached;
          } else {
            _logger.d('Cache stale, refreshing in background', data: {'age': age.inMinutes});
            // Return stale cache but refresh in background
            _backgroundRefresh(mosqueId, targetDate);
            return cached;
          }
        }
      } on DatabaseException catch (e) {
        _logger.w('Cache read failed', error: e);
      }
    }

    // Fetch from remote
    try {
      final times = await _retryHandler.execute(
        () async {
          await _connectivity.ensureConnected();
          return await _provider.getPrayerTimes(mosqueId, date: targetDate);
        },
        operationName: 'getPrayerTimes',
      );

      // Cache the result
      try {
        await _database.cachePrayerTimes(times);
      } on DatabaseException catch (e) {
        _logger.w('Failed to cache prayer times', error: e);
      }

      return times;
    } on NoConnectionException {
      // Try to return cached even if stale
      final cached = await _database.getCachedPrayerTimes(mosqueId, targetDate);
      if (cached != null) {
        _logger.i('Returning stale cache due to no connection');
        return cached;
      }
      rethrow;
    } on Exception catch (e) {
      _logger.e('Get prayer times failed', error: e);
      
      // Try to return cached even if stale
      final cached = await _database.getCachedPrayerTimes(mosqueId, targetDate);
      if (cached != null) {
        return cached;
      }
      
      throw RepositoryException(
        'Failed to load prayer times: ${_getUserFriendlyError(e)}',
        originalError: e,
      );
    }
  }

  /// Get mosque details with caching
  Future<Mosque> getMosqueDetails(String mosqueId) async {
    try {
      // Try local first
      final local = await _database.getMosque(mosqueId);

      try {
        await _connectivity.ensureConnected();
        final remote = await _retryHandler.execute(
          () => _provider.getMosqueDetails(mosqueId),
          operationName: 'getMosqueDetails',
        );
        
        // Update cache
        await _database.insertMosque(remote);
        return remote;
      } on NoConnectionException {
        if (local != null) return local;
        rethrow;
      } on Exception catch (e) {
        _logger.w('Failed to fetch mosque details, using cache', error: e);
        if (local != null) return local;
        throw RepositoryException(
          'Failed to load mosque details: ${_getUserFriendlyError(e)}',
          originalError: e,
        );
      }
    } on DatabaseException catch (e) {
      _logger.e('Database error', error: e);
      // Try remote only
      return await _provider.getMosqueDetails(mosqueId);
    }
  }

  /// Get favorite mosques
  Future<List<Mosque>> getFavoriteMosques() => _database.getFavoriteMosques();

  /// Get active mosque
  Future<Mosque?> getActiveMosque() => _database.getActiveMosque();

  /// Set favorite status
  Future<void> setFavorite(String mosqueId, bool favorite) =>
      _database.setFavorite(mosqueId, favorite);

  /// Set active mosque
  Future<void> setActiveMosque(String mosqueId) =>
      _database.setActiveMosque(mosqueId);

  /// Set travel time for mosque
  Future<void> setTravelTime(String mosqueId, int seconds) =>
      _database.setTravelTime(mosqueId, seconds);

  /// Get travel time for mosque
  Future<int> getTravelTime(String mosqueId) =>
      _database.getTravelTime(mosqueId);

  /// Check if we have cached prayer times
  Future<bool> hasCachedPrayerTimes(String mosqueId, DateTime date) =>
      _database.hasCachedPrayerTimes(mosqueId, date);

  /// Clear old cache
  Future<void> clearOldCache({int daysToKeep = 7}) =>
      _database.clearOldCache(daysToKeep: daysToKeep);

  // Helper methods

  void _cacheMosquesAsync(List<Mosque> mosques) {
    Future.microtask(() async {
      for (final mosque in mosques) {
        try {
          await _database.insertMosque(mosque);
        } catch (e) {
          _logger.w('Failed to cache mosque ${mosque.id}', error: e);
        }
      }
    });
  }

  Future<List<Mosque>> _getCachedMosquesMatching(String query) async {
    try {
      final allFavorites = await _database.getFavoriteMosques();
      final queryLower = query.toLowerCase();
      
      return allFavorites.where((m) {
        return m.name.toLowerCase().contains(queryLower) ||
            (m.city?.toLowerCase().contains(queryLower) ?? false);
      }).toList();
    } on DatabaseException catch (e) {
      _logger.e('Failed to read cache', error: e);
      return [];
    }
  }

  Future<List<Mosque>> _getCachedNearbyMosques(GeoLocation location) async {
    try {
      final favorites = await _database.getFavoriteMosques();
      
      favorites.sort((a, b) {
        final distA = a.latitude != null && a.longitude != null
            ? location.distanceTo(GeoLocation(latitude: a.latitude!, longitude: a.longitude!))
            : double.infinity;
        final distB = b.latitude != null && b.longitude != null
            ? location.distanceTo(GeoLocation(latitude: b.latitude!, longitude: b.longitude!))
            : double.infinity;
        return distA.compareTo(distB);
      });
      
      return favorites;
    } on DatabaseException catch (e) {
      _logger.e('Failed to read cache', error: e);
      return [];
    }
  }

  Future<void> _backgroundRefresh(String mosqueId, DateTime date) async {
    try {
      await _connectivity.ensureConnected();
      final times = await _provider.getPrayerTimes(mosqueId, date: date);
      await _database.cachePrayerTimes(times);
      _logger.d('Background refresh completed');
    } catch (e) {
      _logger.d('Background refresh failed', error: e);
    }
  }

  String _getUserFriendlyError(Exception e) {
    if (e is NoConnectionException) {
      return 'No internet connection. Please check your network settings.';
    }
    if (e is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    if (e is ServerException) {
      return 'Server error. Please try again later.';
    }
    if (e is NotFoundException) {
      return 'Resource not found.';
    }
    return 'An unexpected error occurred.';
  }
}

/// Custom exception for repository errors
class RepositoryException implements Exception {
  final String message;
  final dynamic originalError;

  const RepositoryException(this.message, {this.originalError});

  @override
  String toString() => 'RepositoryException: $message';
}
