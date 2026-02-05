import 'dart:convert';
import 'package:dio/dio.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/entities/geo_location.dart';
import 'prayer_data_provider.dart';

/// Provider A: Official/Private API
/// Uses token-based authentication with configurable base URL
class OfficialApiProvider implements PrayerDataProvider {
  late Dio _dio;
  String? _baseUrl;
  String? _apiToken;
  
  @override
  String get id => 'official_api';
  
  @override
  String get name => 'Official Mawaqit API';
  
  @override
  String get description => 'Direct access to official Mawaqit API (requires credentials)';
  
  @override
  List<ConfigField> get configSchema => [
    const ConfigField(
      key: 'baseUrl',
      label: 'API Base URL',
      type: ConfigFieldType.url,
      required: true,
      description: 'e.g., https://mawaqit.net/api',
    ),
    const ConfigField(
      key: 'apiToken',
      label: 'API Token',
      type: ConfigFieldType.password,
      required: true,
      description: 'Your Mawaqit API token',
    ),
    const ConfigField(
      key: 'timeout',
      label: 'Request Timeout (seconds)',
      type: ConfigFieldType.number,
      defaultValue: '30',
    ),
  ];

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _baseUrl = config['baseUrl'] as String?;
    _apiToken = config['apiToken'] as String?;
    final timeout = int.tryParse(config['timeout']?.toString() ?? '30') ?? 30;
    
    if (_baseUrl == null || _apiToken == null) {
      throw const ProviderException(
        message: 'Base URL and API token are required',
        providerId: 'official_api',
      );
    }

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl!,
      connectTimeout: Duration(seconds: timeout),
      receiveTimeout: Duration(seconds: timeout),
      headers: {
        'Authorization': 'Bearer $_apiToken',
        'Accept': 'application/json',
        'User-Agent': 'IqamahApp/1.0',
      },
    ));

    // Add interceptor for logging
    _dio.interceptors.add(LogInterceptor(
      request: true,
      responseBody: true,
      error: true,
    ));
  }

  @override
  Future<List<Mosque>> searchMosques(String query, {GeoLocation? location}) async {
    try {
      final response = await _dio.get('/mosques/search', queryParameters: {
        'q': query,
        if (location != null) 'lat': location.latitude,
        if (location != null) 'lng': location.longitude,
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['mosques'] ?? [];
        return data.map((json) => _mapMosque(json)).toList();
      }
      
      throw ProviderException(
        message: 'Failed to search mosques: ${response.statusCode}',
        statusCode: response.statusCode,
        providerId: id,
      );
    } on DioException catch (e) {
      throw ProviderException(
        message: 'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
        providerId: id,
      );
    }
  }

  @override
  Future<List<Mosque>> getNearbyMosques(GeoLocation location, {double radiusKm = 10}) async {
    try {
      final response = await _dio.get('/mosques/nearby', queryParameters: {
        'lat': location.latitude,
        'lng': location.longitude,
        'radius': radiusKm,
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['mosques'] ?? [];
        return data.map((json) => _mapMosque(json)).toList();
      }
      
      throw ProviderException(
        message: 'Failed to get nearby mosques: ${response.statusCode}',
        statusCode: response.statusCode,
        providerId: id,
      );
    } on DioException catch (e) {
      throw ProviderException(
        message: 'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
        providerId: id,
      );
    }
  }

  @override
  Future<PrayerTimes> getPrayerTimes(String mosqueId, {DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final response = await _dio.get('/mosques/$mosqueId/times', queryParameters: {
        'date': '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}',
      });

      if (response.statusCode == 200) {
        return _mapPrayerTimes(response.data, mosqueId);
      }
      
      throw ProviderException(
        message: 'Failed to get prayer times: ${response.statusCode}',
        statusCode: response.statusCode,
        providerId: id,
      );
    } on DioException catch (e) {
      throw ProviderException(
        message: 'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
        providerId: id,
      );
    }
  }

  @override
  Future<Mosque> getMosqueDetails(String mosqueId) async {
    try {
      final response = await _dio.get('/mosques/$mosqueId');

      if (response.statusCode == 200) {
        return _mapMosque(response.data);
      }
      
      throw ProviderException(
        message: 'Failed to get mosque details: ${response.statusCode}',
        statusCode: response.statusCode,
        providerId: id,
      );
    } on DioException catch (e) {
      throw ProviderException(
        message: 'Network error: ${e.message}',
        statusCode: e.response?.statusCode,
        providerId: id,
      );
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/status');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Mosque _mapMosque(Map<String, dynamic> json) {
    return Mosque(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['mosque_name'] ?? 'Unknown Mosque',
      address: json['address'] ?? json['localisation'] ?? json['street'],
      city: json['city'] ?? json['ville'],
      country: json['country'] ?? json['pays'],
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
    );
  }

  PrayerTimes _mapPrayerTimes(Map<String, dynamic> json, String mosqueId) {
    final date = DateTime.parse(json['date']?.toString() ?? DateTime.now().toIso8601String());
    final times = json['times'] ?? json;

    return PrayerTimes(
      date: date,
      mosqueId: mosqueId,
      cachedAt: DateTime.now(),
      fajr: _parsePrayer('Fajr', times['fajr'] ?? times['Fajr'] ?? times['sobh'], date),
      dhuhr: _parsePrayer('Dhuhr', times['dhuhr'] ?? times['Dhuhr'] ?? times['duhr'], date),
      asr: _parsePrayer('Asr', times['asr'] ?? times['Asr'], date),
      maghrib: _parsePrayer('Maghrib', times['maghrib'] ?? times['Maghrib'], date),
      isha: _parsePrayer('Isha', times['isha'] ?? times['Isha'], date),
      jumuah: times['jumuah'] != null || times['Jumuah'] != null
        ? _parsePrayer('Jumuah', times['jumuah'] ?? times['Jumuah'], date)
        : null,
    );
  }

  Prayer _parsePrayer(String name, dynamic data, DateTime baseDate) {
    if (data == null) {
      return Prayer(name: name, adhan: baseDate, iqama: null);
    }

    if (data is Map) {
      return Prayer(
        name: name,
        adhan: _parseTime(data['adhan'] ?? data['time'] ?? data, baseDate),
        iqama: data['iqama'] != null ? _parseTime(data['iqama'], baseDate) : null,
      );
    }

    // Single time string - assume it's adhan
    return Prayer(
      name: name,
      adhan: _parseTime(data, baseDate),
      iqama: null,
    );
  }

  DateTime _parseTime(dynamic timeData, DateTime baseDate) {
    if (timeData is DateTime) return timeData;
    
    final timeStr = timeData.toString();
    final parts = timeStr.split(':');
    
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    }
    
    return baseDate;
  }

  @override
  void dispose() {
    _dio.close();
  }
}
