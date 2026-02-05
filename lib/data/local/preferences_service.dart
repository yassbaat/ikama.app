import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/services/prayer_engine.dart';

/// Service for managing user preferences
class PreferencesService {
  static const String _keyActiveProvider = 'active_provider';
  static const String _keyProviderConfig = 'provider_config_';
  static const String _keyRakahDuration = 'rakah_duration_seconds';
  static const String _keyStartLag = 'start_lag_seconds';
  static const String _keyBufferBeforeStart = 'buffer_before_start_seconds';
  static const String _keyNotificationThresholds = 'notification_thresholds';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyLanguage = 'language';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyShowDisclaimer = 'show_disclaimer';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // Provider settings
  String? getActiveProvider() => _prefs.getString(_keyActiveProvider);
  
  Future<void> setActiveProvider(String providerId) => 
    _prefs.setString(_keyActiveProvider, providerId);

  Map<String, dynamic>? getProviderConfig(String providerId) {
    final json = _prefs.getString('$_keyProviderConfig$providerId');
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setProviderConfig(String providerId, Map<String, dynamic> config) => 
    _prefs.setString('$_keyProviderConfig$providerId', jsonEncode(config));

  // Prayer engine config
  PrayerEngineConfig getPrayerEngineConfig() {
    return PrayerEngineConfig(
      rakahDurationSeconds: _prefs.getInt(_keyRakahDuration) ?? 144,
      startLagSeconds: _prefs.getInt(_keyStartLag) ?? 0,
      bufferBeforeStartSeconds: _prefs.getInt(_keyBufferBeforeStart) ?? 30,
    );
  }

  Future<void> setPrayerEngineConfig(PrayerEngineConfig config) async {
    await _prefs.setInt(_keyRakahDuration, config.rakahDurationSeconds);
    await _prefs.setInt(_keyStartLag, config.startLagSeconds);
    await _prefs.setInt(_keyBufferBeforeStart, config.bufferBeforeStartSeconds);
  }

  int getRakahDurationSeconds() => _prefs.getInt(_keyRakahDuration) ?? 144;
  Future<void> setRakahDurationSeconds(int seconds) => 
    _prefs.setInt(_keyRakahDuration, seconds);

  int getStartLagSeconds() => _prefs.getInt(_keyStartLag) ?? 0;
  Future<void> setStartLagSeconds(int seconds) => 
    _prefs.setInt(_keyStartLag, seconds);

  int getBufferBeforeStartSeconds() => _prefs.getInt(_keyBufferBeforeStart) ?? 30;
  Future<void> setBufferBeforeStartSeconds(int seconds) => 
    _prefs.setInt(_keyBufferBeforeStart, seconds);

  // Notification thresholds
  List<int> getNotificationThresholds() {
    final json = _prefs.getString(_keyNotificationThresholds);
    if (json == null) {
      return [15, 10, 5, 2, 1]; // Default: 15, 10, 5, 2, 1 minutes
    }
    try {
      return (jsonDecode(json) as List).map((e) => e as int).toList();
    } catch (_) {
      return [15, 10, 5, 2, 1];
    }
  }

  Future<void> setNotificationThresholds(List<int> thresholds) => 
    _prefs.setString(_keyNotificationThresholds, jsonEncode(thresholds));

  // App settings
  bool getDarkMode() => _prefs.getBool(_keyDarkMode) ?? false;
  Future<void> setDarkMode(bool enabled) => _prefs.setBool(_keyDarkMode, enabled);

  String? getLanguage() => _prefs.getString(_keyLanguage);
  Future<void> setLanguage(String language) => _prefs.setString(_keyLanguage, language);

  bool getIsFirstLaunch() => _prefs.getBool(_keyFirstLaunch) ?? true;
  Future<void> setFirstLaunchComplete() => _prefs.setBool(_keyFirstLaunch, false);

  bool getShowDisclaimer() => _prefs.getBool(_keyShowDisclaimer) ?? true;
  Future<void> setShowDisclaimer(bool show) => _prefs.setBool(_keyShowDisclaimer, show);

  // Clear all settings
  Future<void> clearAll() => _prefs.clear();
}
