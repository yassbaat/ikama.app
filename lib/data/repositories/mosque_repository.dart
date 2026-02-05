import '../../domain/entities/mosque.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/entities/geo_location.dart';
import '../local/database_helper.dart';
import '../providers/prayer_data_provider.dart';

/// Repository for mosque-related operations
/// Handles data source coordination (local cache + remote provider)
class MosqueRepository {
  final PrayerDataProvider _provider;
  final DatabaseHelper _database;

  MosqueRepository({
    required PrayerDataProvider provider,
    DatabaseHelper? database,
  })  : _provider = provider,
        _database = database ?? DatabaseHelper.instance;

  /// Search mosques - always fetches from remote, caches results
  Future<List<Mosque>> searchMosques(String query, {GeoLocation? location}) async {
    try {
      final results = await _provider.searchMosques(query, location: location);
      
      // Cache results
      for (final mosque in results) {
        await _database.insertMosque(mosque);
      }
      
      return results;
    } catch (e) {
      // On error, return cached mosques matching query
      final allFavorites = await _database.getFavoriteMosques();
      return allFavorites.where((m) => 
        m.name.toLowerCase().contains(query.toLowerCase()) ||
        (m.city?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();
    }
  }

  /// Get nearby mosques
  Future<List<Mosque>> getNearbyMosques(GeoLocation location, {double radiusKm = 10}) async {
    try {
      final results = await _provider.getNearbyMosques(location, radiusKm: radiusKm);
      
      // Cache results
      for (final mosque in results) {
        await _database.insertMosque(mosque);
      }
      
      return results;
    } catch (e) {
      // Return favorites sorted by distance
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
    }
  }

  /// Get mosque details
  Future<Mosque> getMosqueDetails(String mosqueId) async {
    // Try local first
    final local = await _database.getMosque(mosqueId);
    
    try {
      final remote = await _provider.getMosqueDetails(mosqueId);
      await _database.insertMosque(remote);
      return remote;
    } catch (e) {
      if (local != null) {
        return local;
      }
      rethrow;
    }
  }

  /// Get prayer times with caching
  Future<PrayerTimes> getPrayerTimes(String mosqueId, {DateTime? date, bool forceRefresh = false}) async {
    final targetDate = date ?? DateTime.now();
    
    // Check cache first unless force refresh
    if (!forceRefresh) {
      final cached = await _database.getCachedPrayerTimes(mosqueId, targetDate);
      if (cached != null) {
        // Return cached data but also refresh in background if stale
        _backgroundRefresh(mosqueId, targetDate);
        return cached;
      }
    }
    
    // Fetch from remote
    try {
      final times = await _provider.getPrayerTimes(mosqueId, date: targetDate);
      await _database.cachePrayerTimes(times);
      return times;
    } catch (e) {
      // Try to return cached even if force refresh
      final cached = await _database.getCachedPrayerTimes(mosqueId, targetDate);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Refresh prayer times in background
  Future<void> _backgroundRefresh(String mosqueId, DateTime date) async {
    try {
      final times = await _provider.getPrayerTimes(mosqueId, date: date);
      await _database.cachePrayerTimes(times);
    } catch (_) {
      // Ignore background refresh errors
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
}
