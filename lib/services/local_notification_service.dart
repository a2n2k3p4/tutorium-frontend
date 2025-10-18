import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    debugPrint('✅ [LocalNotification] Service initialized');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      '🔔 [LocalNotification] Notification tapped: ${response.payload}',
    );
    // You can navigate to specific page based on payload
  }

  /// Request permissions (mainly for iOS)
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidImplementation
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'class_channel',
      'Class Notifications',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('🔔 [LocalNotification] Showed notification: $title');
  }

  /// Schedule notification at specific time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      'class_reminder_channel',
      'Class Reminders',
      channelDescription: 'Reminders for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.aiff',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    debugPrint(
      '⏰ [LocalNotification] Scheduled notification: $title at $scheduledTime',
    );
  }

  /// Schedule multiple reminders for a class
  Future<void> scheduleClassReminders({
    required int classSessionId,
    required String className,
    required DateTime classStartTime,
  }) async {
    final now = DateTime.now();

    // Define reminder intervals: 1 hour, 30 min, 10 min, 5 min, 1 min
    final reminders = [
      {'minutes': 60, 'label': '1 hour'},
      {'minutes': 30, 'label': '30 minutes'},
      {'minutes': 10, 'label': '10 minutes'},
      {'minutes': 5, 'label': '5 minutes'},
      {'minutes': 1, 'label': '1 minute'},
    ];

    for (int i = 0; i < reminders.length; i++) {
      final minutes = reminders[i]['minutes'] as int;
      final label = reminders[i]['label'] as String;

      final reminderTime = classStartTime.subtract(Duration(minutes: minutes));

      // Only schedule if reminder time is in the future
      if (reminderTime.isAfter(now)) {
        final notificationId = _generateNotificationId(classSessionId, minutes);

        await scheduleNotification(
          id: notificationId,
          title: '🔔 Class Starting Soon!',
          body: '$className starts in $label',
          scheduledTime: reminderTime,
          payload: 'class_reminder:$classSessionId',
        );

        debugPrint(
          '✅ [ClassReminder] Scheduled $label reminder for class $classSessionId',
        );
      } else {
        debugPrint(
          '⏭️  [ClassReminder] Skipped $label reminder (already passed)',
        );
      }
    }
  }

  /// Generate unique notification ID for class reminders
  int _generateNotificationId(int classSessionId, int minutesBefore) {
    // Use classSessionId and minutes to create unique ID
    // Format: [classSessionId][minutesBefore]
    // Example: class 123, 60 minutes = 12360
    return int.parse('$classSessionId$minutesBefore');
  }

  /// Cancel all reminders for a specific class
  Future<void> cancelClassReminders(int classSessionId) async {
    final reminderMinutes = [60, 30, 10, 5, 1];

    for (final minutes in reminderMinutes) {
      final notificationId = _generateNotificationId(classSessionId, minutes);
      await _notificationsPlugin.cancel(notificationId);
      debugPrint(
        '❌ [ClassReminder] Cancelled $minutes min reminder for class $classSessionId',
      );
    }
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint('❌ [LocalNotification] Cancelled notification: $id');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint('❌ [LocalNotification] Cancelled all notifications');
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Show beautiful enrollment success notification
  Future<void> showEnrollmentSuccess({
    required String className,
    required DateTime classStartTime,
  }) async {
    final timeStr = _formatDateTime(classStartTime);

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '✅ Enrollment Successful!',
      body: 'You are enrolled in "$className"\nClass starts at $timeStr',
      payload: 'enrollment_success',
    );
  }

  /// Show class starting now notification
  Future<void> showClassStartingNow({
    required int classSessionId,
    required String className,
  }) async {
    await showNotification(
      id: classSessionId,
      title: '🎓 Class Starting Now!',
      body: '$className is starting. Join now!',
      payload: 'class_starting:$classSessionId',
    );
  }

  /// Show class cancelled notification
  Future<void> showClassCancelled({
    required String className,
    required String reason,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '⚠️ Class Cancelled',
      body: '$className has been cancelled. Reason: $reason',
      payload: 'class_cancelled',
    );
  }

  /// Format DateTime to readable string
  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year at $hour:$minute';
  }
}
