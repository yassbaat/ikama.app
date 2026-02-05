import 'dart:async';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import '../../domain/entities/mosque.dart';
import '../../domain/entities/prayer_times.dart';
import '../../domain/entities/geo_location.dart';
import 'prayer_data_provider.dart';

/// Provider C: HTML Scraping Fallback
/// Scrapes Mawaqit website for prayer times
class ScrapingProvider implements PrayerDataProvider {
  late Dio _dio;
  final _rateLimiter = _RateLimiter(minInterval: const Duration(seconds: 30));
  
  @override
  String get id => 'scraping';
  
  @override
  String get name => 'Web Scraping (Fallback)';
  
  @override
  String get description => 'Scrapes Mawaqit website directly (slower, use as fallback)';
  
  @override
  List<ConfigField> get configSchema => [
    const ConfigField(
      key: 'baseUrl',
      label: 'Mawaqit Base URL',
      type: ConfigFieldType.url,
      required: false,
      defaultValue: 'https://mawaqit.net',
      description: 'Base URL for Mawaqit website',
    ),
    const ConfigField(
      key: 'timeout',
      label: 'Request Timeout (seconds)',
      type: ConfigFieldType.number,
      defaultValue: '45',
    ),
    const ConfigField(
      key: 'enableCache',
      label: 'Enable HTML Caching',
      type: ConfigFieldType.boolean,
      defaultValue: 'true',
      description: 'Cache raw HTML for debugging',
    ),
  ];

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final baseUrl = config['baseUrl'] as String? ?? 'https://mawaqit.net';
    final timeout = int.tryParse(config['timeout']?.toString() ?? '45') ?? 45;

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: timeout),
      receiveTimeout: Duration(seconds: timeout),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ));
  }

  @override
  Future<List<Mosque>> searchMosques(String query, {GeoLocation? location}) async {
    await _rateLimiter.throttle();
    
    try {
      // Mawaqit search URL
      final response = await _dio.get('/en/search', queryParameters: {
        'q': query,
        if (location != null) ...{
          'lat': location.latitude,
          'lng': location.longitude,
        },
      });

      if (response.statusCode == 200) {
        return _parseSearchResults(response.data as String);
      }
      
      throw ProviderException(
        message: 'Search failed: ${response.statusCode}',
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
    await _rateLimiter.throttle();
    
    try {
      final response = await _dio.get('/en/nearby', queryParameters: {
        'lat': location.latitude,
        'lng': location.longitude,
        'radius': radiusKm,
      });

      if (response.statusCode == 200) {
        return _parseSearchResults(response.data as String);
      }
      
      throw ProviderException(
        message: 'Nearby search failed: ${response.statusCode}',
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
    await _rateLimiter.throttle();
    
    try {
      final response = await _dio.get('/en/m/$mosqueId');

      if (response.statusCode == 200) {
        final html = response.data as String;
        return _parsePrayerTimes(html, mosqueId, date ?? DateTime.now());
      }
      
      throw ProviderException(
        message: 'Failed to fetch times: ${response.statusCode}',
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
    await _rateLimiter.throttle();
    
    try {
      final response = await _dio.get('/en/m/$mosqueId');

      if (response.statusCode == 200) {
        return _parseMosqueDetails(response.data as String, mosqueId);
      }
      
      throw ProviderException(
        message: 'Failed to fetch details: ${response.statusCode}',
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
      final response = await _dio.get('/en');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  List<Mosque> _parseSearchResults(String html) {
    final document = parse(html);
    final mosques = <Mosque>[];

    // Try multiple selectors for mosque listings
    final selectors = [
      '.mosque-item',
      '.mosque',
      '[data-mosque-id]',
      '.search-result',
      '.mosquee',
      '.card',
    ];

    for (final selector in selectors) {
      final elements = document.querySelectorAll(selector);
      if (elements.isNotEmpty) {
        for (final element in elements) {
          final id = element.attributes['data-id'] ??
              element.attributes['data-mosque-id'] ??
              _extractIdFromHref(element.querySelector('a')?.attributes['href']);
          
          final name = element.querySelector('.name, .title, h2, h3, h4')?.text.trim() ??
              element.text.split('\n').first.trim();
          
          final address = element.querySelector('.address, .location, .adresse')?.text.trim();
          
          if (id != null && name.isNotEmpty) {
            mosques.add(Mosque(
              id: id,
              name: name,
              address: address,
            ));
          }
        }
        break;
      }
    }

    return mosques;
  }

  String? _extractIdFromHref(String? href) {
    if (href == null) return null;
    final match = RegExp(r'/m/([^/]+)').firstMatch(href);
    return match?.group(1);
  }

  Mosque _parseMosqueDetails(String html, String mosqueId) {
    final document = parse(html);

    final name = document.querySelector('h1, .mosque-name, .page-title')?.text.trim() ??
        document.querySelector('[data-mosque-name]')?.attributes['data-mosque-name'] ??
        'Unknown Mosque';

    final address = document.querySelector('.address, .mosque-address, [data-address]')?.text.trim() ??
        document.querySelector('[data-address]')?.attributes['data-address'];

    final latStr = document.querySelector('[data-lat]')?.attributes['data-lat'] ??
        document.querySelector('[data-latitude]')?.attributes['data-latitude'];
    final lngStr = document.querySelector('[data-lng]')?.attributes['data-lng'] ??
        document.querySelector('[data-longitude]')?.attributes['data-longitude'];

    return Mosque(
      id: mosqueId,
      name: name,
      address: address,
      latitude: latStr != null ? double.tryParse(latStr) : null,
      longitude: lngStr != null ? double.tryParse(lngStr) : null,
    );
  }

  PrayerTimes _parsePrayerTimes(String html, String mosqueId, DateTime date) {
    final document = parse(html);

    // Look for prayer times in various formats
    final prayers = <String, Prayer>{};
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    for (final name in prayerNames) {
      final prayer = _findPrayerTime(document, name, date);
      if (prayer != null) {
        prayers[name] = prayer;
      }
    }

    // Look for Jumuah
    final jumuah = _findPrayerTime(document, 'Jumuah', date) ??
        _findPrayerTime(document, 'Jumua', date) ??
        _findPrayerTime(document, 'Friday', date);

    if (prayers.length < 5) {
      throw ProviderException(
        message: 'Could not parse all prayer times from page',
        providerId: id,
      );
    }

    return PrayerTimes(
      date: date,
      mosqueId: mosqueId,
      cachedAt: DateTime.now(),
      fajr: prayers['Fajr']!,
      dhuhr: prayers['Dhuhr']!,
      asr: prayers['Asr']!,
      maghrib: prayers['Maghrib']!,
      isha: prayers['Isha']!,
      jumuah: jumuah,
    );
  }

  Prayer? _findPrayerTime(dynamic document, String prayerName, DateTime baseDate) {
    final selectors = [
      '[data-prayer="$prayerName"]',
      '[data-name="$prayerName"]',
      '.prayer-$prayerName',
      '#prayer-$prayerName',
      '.${prayerName.toLowerCase()}',
      '#${prayerName.toLowerCase()}',
    ];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final adhanTime = element.querySelector('.adhan, .athan, .time-start, [data-time="adhan"]')?.text.trim() ??
            element.attributes['data-adhan'] ??
            element.attributes['data-time'];

        final iqamaTime = element.querySelector('.iqama, .iqamah, .time-iqama, [data-time="iqama"]')?.text.trim() ??
            element.attributes['data-iqama'] ??
            element.attributes['data-iqamah'];

        if (adhanTime != null) {
          return Prayer(
            name: prayerName,
            adhan: _parseTimeString(adhanTime, baseDate),
            iqama: iqamaTime != null ? _parseTimeString(iqamaTime, baseDate) : null,
          );
        }
      }
    }

    return null;
  }

  DateTime _parseTimeString(String timeStr, DateTime baseDate) {
    final trimmed = timeStr.trim();
    final parts = trimmed.split(':');
    
    if (parts.length >= 2) {
      var hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      // Handle AM/PM
      if (trimmed.toLowerCase().contains('pm') && hour != 12) {
        hour += 12;
      } else if (trimmed.toLowerCase().contains('am') && hour == 12) {
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

/// Simple rate limiter to avoid hammering servers
class _RateLimiter {
  final Duration minInterval;
  DateTime? _lastRequest;

  _RateLimiter({required this.minInterval});

  Future<void> throttle() async {
    if (_lastRequest != null) {
      final elapsed = DateTime.now().difference(_lastRequest!);
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
    }
    _lastRequest = DateTime.now();
  }
}
