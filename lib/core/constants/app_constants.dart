/// App-wide constants
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Iqamah';
  static const String appVersion = '1.0.0';

  // Default prayer engine settings
  static const int defaultRakahDurationSeconds = 144; // 2.4 minutes
  static const int defaultStartLagSeconds = 0;
  static const int defaultBufferBeforeStartSeconds = 30;
  static const int defaultGraceSeconds = 60;

  // Default rak'ah counts
  static const Map<String, int> defaultRakahCounts = {
    'Fajr': 2,
    'Dhuhr': 4,
    'Asr': 4,
    'Maghrib': 3,
    'Isha': 4,
    'Jumuah': 2,
  };

  // Default notification thresholds (minutes before iqama)
  static const List<int> defaultNotificationThresholds = [15, 10, 5, 2, 1];

  // Cache settings
  static const int cacheValidityHours = 24;
  static const int maxCacheDays = 7;

  // API settings
  static const int defaultRequestTimeout = 30;
  static const int maxRetries = 3;

  // UI constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const Duration countdownUpdateInterval = Duration(seconds: 1);
}
