import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../../core/utils/logger.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/preferences_service.dart';
import '../../domain/entities/prayer.dart';
import '../../domain/services/prayer_engine.dart';
import '../notifications/notification_service.dart';

/// Background task identifiers
class BackgroundTask {
  static const String refreshPrayerTimes = 'refresh_prayer_times';
  static const String scheduleNotifications = 'schedule_notifications';
  static const String cleanupCache = 'cleanup_cache';
  static const String checkPrayerStatus = 'check_prayer_status';
  
  /// All registered tasks
  static const List<String> allTasks = [
    refreshPrayerTimes,
    scheduleNotifications,
    cleanupCache,
    checkPrayerStatus,
  ];
}

/// Callback dispatcher for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final handler = BackgroundTaskHandler();
    
    try {
      return await handler.handleTask(task, inputData);
    } catch (e, stackTrace) {
      AppLogger().e(
        'Background task failed: $task',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  });
}

/// Handles background task execution
class BackgroundTaskHandler {
  final AppLogger _logger = AppLogger();
  late final DatabaseHelper _database;
  late final PreferencesService _prefs;
  late final NotificationService _notifications;
  late final PrayerEngine _engine;

  BackgroundTaskHandler() {
    _database = DatabaseHelper.instance;
    _prefs = PreferencesService();
    _notifications = NotificationService();
    _engine = PrayerEngine(config: _prefs.getPrayerEngineConfig());
  }

  Future<bool> handleTask(String task, Map<String, dynamic>? inputData) async {
    _logger.d('Handling background task: $task');

    switch (task) {
      case BackgroundTask.refreshPrayerTimes:
        return await _handleRefreshPrayerTimes(inputData);
      
      case BackgroundTask.scheduleNotifications:
        return await _handleScheduleNotifications(inputData);
      
      case BackgroundTask.cleanupCache:
        return await _handleCleanupCache();
      
      case BackgroundTask.checkPrayerStatus:
        return await _handleCheckPrayerStatus(inputData);
      
      default:
        _logger.w('Unknown background task: $task');
        return false;
    }
  }

  Future<bool> _handleRefreshPrayerTimes(Map<String, dynamic>? inputData) async {
    try {
      final mosqueId = inputData?['mosqueId'] as String?;
      if (mosqueId == null) {
        _logger.w('No mosqueId provided for prayer times refresh');
        return false;
      }

      // This would need the provider to be initialized
      // For now, we just log the intent
      _logger.i('Would refresh prayer times for mosque: $mosqueId');
      
      return true;
    } catch (e) {
      _logger.e('Failed to refresh prayer times', error: e);
      return false;
    }
  }

  Future<bool> _handleScheduleNotifications(Map<String, dynamic>? inputData) async {
    try {
      await _notifications.initialize();
      
      final mosqueId = inputData?['mosqueId'] as String?;
      if (mosqueId == null) {
        _logger.w('No mosqueId provided for notification scheduling');
        return false;
      }

      // Get cached prayer times
      final times = await _database.getCachedPrayerTimes(mosqueId, DateTime.now());
      if (times == null) {
        _logger.w('No cached prayer times for notifications');
        return false;
      }

      // Get notification thresholds
      final thresholds = _prefs.getNotificationThresholds();
      
      // Schedule notifications for each prayer
      final prayers = times.allPrayers;
      for (final prayer in prayers) {
        if (prayer.iqama != null) {
          await _notifications.schedulePrayerReminders(
            prayer,
            minutesBefore: thresholds,
          );
        }
      }

      _logger.i('Scheduled notifications for ${prayers.length} prayers');
      return true;
    } catch (e) {
      _logger.e('Failed to schedule notifications', error: e);
      return false;
    }
  }

  Future<bool> _handleCleanupCache() async {
    try {
      await _database.clearOldCache(daysToKeep: 7);
      _logger.i('Cache cleanup completed');
      return true;
    } catch (e) {
      _logger.e('Failed to cleanup cache', error: e);
      return false;
    }
  }

  Future<bool> _handleCheckPrayerStatus(Map<String, dynamic>? inputData) async {
    try {
      final mosqueId = inputData?['mosqueId'] as String?;
      if (mosqueId == null) return false;

      final times = await _database.getCachedPrayerTimes(mosqueId, DateTime.now());
      if (times == null) return false;

      final now = DateTime.now();
      final nextPrayer = _engine.getNextPrayer(times, now);

      // Check if prayer is starting soon (within 2 minutes)
      if (nextPrayer.timeUntilIqama != null &&
          nextPrayer.timeUntilIqama!.inMinutes <= 2 &&
          nextPrayer.timeUntilIqama!.inSeconds > 0) {
        
        await _notifications.showOngoingNotification(
          id: nextPrayer.prayer.name.hashCode,
          title: '${nextPrayer.prayer.name} Iqama Soon',
          body: 'Iqama in ${_engine.formatDuration(nextPrayer.timeUntilIqama!)}',
          payload: nextPrayer.prayer.name,
        );
      }

      return true;
    } catch (e) {
      _logger.e('Failed to check prayer status', error: e);
      return false;
    }
  }
}

/// Main background service for scheduling and managing background tasks
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final AppLogger _logger = AppLogger();
  bool _initialized = false;

  /// Initialize the background service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      
      _initialized = true;
      _logger.i('Background service initialized');
    } catch (e) {
      _logger.e('Failed to initialize background service', error: e);
    }
  }

  /// Schedule periodic prayer time refresh
  Future<void> schedulePrayerTimeRefresh(String mosqueId) async {
    if (!_initialized) return;

    try {
      // Schedule daily refresh at midnight
      await Workmanager().registerPeriodicTask(
        '${BackgroundTask.refreshPrayerTimes}_$mosqueId',
        BackgroundTask.refreshPrayerTimes,
        frequency: const Duration(hours: 6), // Refresh every 6 hours
        inputData: {'mosqueId': mosqueId},
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      _logger.d('Scheduled prayer time refresh for $mosqueId');
    } catch (e) {
      _logger.e('Failed to schedule prayer time refresh', error: e);
    }
  }

  /// Schedule daily notification setup
  Future<void> scheduleDailyNotifications(String mosqueId) async {
    if (!_initialized) return;

    try {
      // Schedule notification setup at 1 AM daily
      await Workmanager().registerPeriodicTask(
        '${BackgroundTask.scheduleNotifications}_$mosqueId',
        BackgroundTask.scheduleNotifications,
        frequency: const Duration(hours: 12),
        inputData: {'mosqueId': mosqueId},
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      _logger.d('Scheduled daily notifications for $mosqueId');
    } catch (e) {
      _logger.e('Failed to schedule daily notifications', error: e);
    }
  }

  /// Schedule cache cleanup
  Future<void> scheduleCacheCleanup() async {
    if (!_initialized) return;

    try {
      await Workmanager().registerPeriodicTask(
        BackgroundTask.cleanupCache,
        BackgroundTask.cleanupCache,
        frequency: const Duration(days: 1),
        constraints: Constraints(
          requiresStorageNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );

      _logger.d('Scheduled cache cleanup');
    } catch (e) {
      _logger.e('Failed to schedule cache cleanup', error: e);
    }
  }

  /// Schedule prayer status check (for ongoing notification)
  Future<void> schedulePrayerStatusCheck(String mosqueId) async {
    if (!_initialized) return;

    try {
      await Workmanager().registerPeriodicTask(
        '${BackgroundTask.checkPrayerStatus}_$mosqueId',
        BackgroundTask.checkPrayerStatus,
        frequency: const Duration(minutes: 1), // Check every minute
        inputData: {'mosqueId': mosqueId},
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      _logger.d('Scheduled prayer status check for $mosqueId');
    } catch (e) {
      _logger.e('Failed to schedule prayer status check', error: e);
    }
  }

  /// Cancel all tasks for a mosque
  Future<void> cancelTasksForMosque(String mosqueId) async {
    if (!_initialized) return;

    try {
      for (final task in BackgroundTask.allTasks) {
        await Workmanager().cancelByUniqueName('${task}_$mosqueId');
      }
      
      _logger.d('Cancelled all tasks for $mosqueId');
    } catch (e) {
      _logger.e('Failed to cancel tasks', error: e);
    }
  }

  /// Cancel all background tasks
  Future<void> cancelAllTasks() async {
    if (!_initialized) return;

    try {
      await Workmanager().cancelAll();
      _logger.i('Cancelled all background tasks');
    } catch (e) {
      _logger.e('Failed to cancel all tasks', error: e);
    }
  }

  /// Dispose resources
  void dispose() {
    // Nothing to dispose for WorkManager
  }
}
