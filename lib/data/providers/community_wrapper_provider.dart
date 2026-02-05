import 'dart:convert';
import 'package:dio/dio.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/entities/geo_location.dart';
import 'prayer_data_provider.dart';

/// Provider B: Community Wrapper API
/// User-supplied REST wrapper endpoint
class CommunityWrapperProvider implements PrayerDataProvider {
  late Dio _dio;
  String? _baseUrl;
  String? _apiKey;
  
  @override
  String get id => 'community_wrapper';
  
  @override
  String get name => 'Community API Wrapper';
  
  @override
  String get description => 'Third-party REST wrapper for Mawaqit data';
  
  @override
  List<ConfigField> get configSchema => [
    const ConfigField(
      key: 'baseUrl',
      label: 'Wrapper Base URL',
      type: ConfigFieldType.url,
      required: true,
      description: 'e.g., https://mawaqit-wrapper.example.com',
    ),
    const ConfigField(
      key: 'apiKey',
      label: 'API Key (optional)',
      type: ConfigFieldType.password,
      required: false,
      description: 'If your wrapper requires authentication',
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
    _apiKey = config['apiKey'] as String?;
    final timeout = int.tryParse(config['timeout']?.toString() ?? '30') ?? 30;
    
    if (_baseUrl == null) {
      throw const ProviderException(
        message: 'Base URL is required',
        providerId: 'community_wrapper',
      );
    }

    // Ensure baseUrl doesn't end with /
    final baseUrl = _baseUrl!.endsWith('/') ? _baseUrl!.substring(0, _baseUrl!.length - 1) : _baseUrl;

    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'IqamahApp/1.0',
    };

    if (_apiKey != null && _apiKey!.isNotEmpty) {
      headers['X-API-Key'] = _apiKey!;
    }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl!,
      connectTimeout: Duration(seconds: timeout),
      receiveTimeout: Duration(seconds: timeout),
      headers: headers,
    ));
  }

  @override
  Future<List<Mosque>> searchMosques(String query, {GeoLocation? location}) async {
    try {
      final response = await _dio.get('/mosques', queryParameters: {
        'search': query,
        if (location != null) ...{
          'lat': location.latitude,
          'lng': location.longitude,
        },
      });

      if (response.statusCode == 200) {
        final List<dynamic> data;
        if (response.data is List) {
          data = response.data as List;
        } else if (response.data is Map) {
          data = (response.data as Map)['data'] ?? (response.data as Map)['mosques'] ?? (response.data as Map)['results'] ?? [];
        } else {
          data = [];
        }
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
        final List<dynamic> data;
        if (response.data is List) {
          data = response.data as List;
        } else {
          data = (response.data as Map)['data'] ?? (response.data as Map)['mosques'] ?? [];
        }
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
        return _mapPrayerTimes(response.data, mosqueId, targetDate);
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
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      // Try alternative endpoints
      try {
        final response = await _dio.get('/');
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  Mosque _mapMosque(Map<String, dynamic> json) {
    // Handle various field naming conventions
    return Mosque(
      id: json['id']?.toString() ?? json['mosque_id']?.toString() ?? '',
      name: json['name'] ?? json['mosque_name'] ?? json['title'] ?? 'Unknown Mosque',
      address: json['address'] ?? json['location'] ?? json['street'] ?? json['address_line'],
      city: json['city'] ?? json['ville'] ?? json['town'],
      country: json['country'] ?? json['pays'] ?? json['nation'],
      latitude: _parseDouble(json['latitude'] ?? json['lat'] ?? json['latitude_deg']),
      longitude: _parseDouble(json['longitude'] ?? json['lng'] ?? json['lon'] ?? json['longitude_deg']),
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  PrayerTimes _mapPrayerTimes(dynamic data, String mosqueId, DateTime date) {
    Map<String, dynamic> times;
    
    if (data is Map) {
      times = (data['times'] ?? data['prayer_times'] ?? data['schedule'] ?? data) as Map<String, dynamic>;
    } else {
      times = {};
    }

    return PrayerTimes(
      date: date,
      mosqueId: mosqueId,
      cachedAt: DateTime.now(),
      fajr: _parsePrayer('Fajr', times['fajr'] ?? times['Fajr'] ?? times['sobh'] ?? times['fajr_adhan'], date),
      dhuhr: _parsePrayer('Dhuhr', times['dhuhr'] ?? times['Dhuhr'] ?? times['duhr'] ?? times['dhuhr_adhan'] ?? times['zuhr'], date),
      asr: _parsePrayer('Asr', times['asr'] ?? times['Asr'] ?? times['asr_adhan'], date),
      maghrib: _parsePrayer('Maghrib', times['maghrib'] ?? times['Maghrib'] ?? times['maghrib_adhan'] ?? times['magreb'], date),
      isha: _parsePrayer('Isha', times['isha'] ?? times['Isha'] ?? times['isha_adhan'], date),
      jumuah: times['jumuah'] != null || times['Jumuah'] != null || times['juma'] != null
        ? _parsePrayer('Jumuah', times['jumuah'] ?? times['Jumuah'] ?? times['juma'], date)
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
        adhan: _parseTime(data['adhan'] ?? data['athan'] ?? data['azan'] ?? data['time'] ?? data['start'] ?? data, baseDate),
        iqama: data['iqama'] != null || data['iqamah'] != null || data['jamaah'] != null
          ? _parseTime(data['iqama'] ?? data['iqamah'] ?? data['jamaah'], baseDate)
          : null,
      );
    }

    return Prayer(
      name: name,
      adhan: _parseTime(data, baseDate),
      iqama: null,
    );
  }

  DateTime _parseTime(dynamic timeData, DateTime baseDate) {
    if (timeData is DateTime) return timeData;
    
    final timeStr = timeData.toString().trim();
    
    // Handle HH:MM format
    final timeParts = timeStr.split(':');
    if (timeParts.length >= 2) {
      var hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      
      // Handle 12-hour format with AM/PM
      if (timeStr.toLowerCase().contains('pm') && hour != 12) {
        hour += 12;
      } else if (timeStr.toLowerCase().contains('am') && hour == 12) {
        hour = 0;
      }
      
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    }
    
    return baseDate;
  }

  @override
  void dispose() {
    _dio.close();
  }
}
