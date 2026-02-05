import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../domain/entities/prayer.dart';

/// Cross-platform notification service
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  final StreamController<String?> _notificationResponseController = 
    StreamController<String?>.broadcast();
  
  Stream<String?> get onNotificationResponse => _notificationResponseController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS/macOS initialization
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (id, title, body, payload) {
        // Legacy iOS callback
      },
    );

    // Linux initialization
    final linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
      defaultIcon: AssetsLinuxIcon('assets/icons/app_icon.png'),
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _notificationResponseController.add(details.payload);
      },
    );

    _initialized = true;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return true;
  }

  /// Schedule notification for a prayer time
  Future<void> schedulePrayerNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_times',
          'Prayer Times',
          channelDescription: 'Notifications for prayer times',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
          autoCancel: true,
          actions: [
            const AndroidNotificationAction(
              'open_app',
              'Open App',
              showsUserInterface: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        linux: const LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.normal,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Show persistent ongoing notification (Android only)
  Future<void> showOngoingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'ongoing_prayer',
          'Ongoing Prayer Countdown',
          channelDescription: 'Persistent notification for next prayer',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          actions: [
            const AndroidNotificationAction(
              'change_mosque',
              'Change Mosque',
            ),
            const AndroidNotificationAction(
              'silence',
              'Silence Today',
            ),
          ],
        ),
      ),
      payload: payload,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Schedule multiple notifications for a prayer
  Future<void> schedulePrayerReminders(
    Prayer prayer, {
    required List<int> minutesBefore,
  }) async {
    if (prayer.iqama == null) return;

    for (final minutes in minutesBefore) {
      final scheduledTime = prayer.iqama!.subtract(Duration(minutes: minutes));
      
      await schedulePrayerNotification(
        id: '${prayer.name}_$minutes'.hashCode,
        title: '${prayer.name} Prayer',
        body: minutes == 0
          ? 'Iqama time now!'
          : 'Iqama in $minutes minutes',
        scheduledTime: scheduledTime,
        payload: prayer.name,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _notificationResponseController.close();
  }
}

// Stub for Linux icon - in production this would be a real asset
class AssetsLinuxIcon {
  final String path;
  const AssetsLinuxIcon(this.path);
}
