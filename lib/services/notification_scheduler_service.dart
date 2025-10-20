import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/service/enrollments.dart';
import 'package:tutorium_frontend/service/class_sessions.dart';
import 'package:tutorium_frontend/service/classes.dart';
import 'package:tutorium_frontend/util/local_storage.dart';
import 'package:tutorium_frontend/services/local_notification_service.dart';

/// Background service to schedule notifications for all enrolled classes
class NotificationSchedulerService {
  static final NotificationSchedulerService _instance =
      NotificationSchedulerService._internal();
  factory NotificationSchedulerService() => _instance;
  NotificationSchedulerService._internal();

  Timer? _schedulerTimer;
  bool _isRunning = false;

  void _log(String message) {
    debugPrint('🔔 [NotificationScheduler] $message');
  }

  /// Start background scheduler
  Future<void> start() async {
    if (_isRunning) {
      _log('Already running');
      return;
    }

    _isRunning = true;
    _log('Starting background scheduler...');

    // Schedule notifications immediately
    await scheduleAllNotifications();

    // Schedule periodic check every 6 hours
    _schedulerTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => scheduleAllNotifications(),
    );

    _log('Background scheduler started (runs every 6 hours)');
  }

  /// Stop background scheduler
  void stop() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _isRunning = false;
    _log('Background scheduler stopped');
  }

  /// Schedule notifications for all enrolled classes
  Future<void> scheduleAllNotifications() async {
    try {
      _log('Scheduling notifications for all enrolled classes...');

      // Get current user's learner ID
      final learnerId = await LocalStorage.getLearnerId();
      if (learnerId == null) {
        _log('No learner ID found, skipping');
        return;
      }

      // Get all active enrollments for this learner
      final allEnrollments = await Enrollment.fetchAll();
      final activeEnrollments = allEnrollments
          .where(
            (e) =>
                e.learnerId == learnerId &&
                e.enrollmentStatus.toLowerCase() == 'active',
          )
          .toList();

      _log('Found ${activeEnrollments.length} active enrollments');

      final now = DateTime.now();
      int scheduled = 0;
      int skipped = 0;

      for (final enrollment in activeEnrollments) {
        try {
          // Get session details
          final session = await ClassSession.fetchById(
            enrollment.classSessionId,
          );
          final classStart = DateTime.parse(session.classStart).toLocal();

          // Only schedule for future classes
          if (classStart.isAfter(now)) {
            // Get class info
            final classInfo = await ClassInfo.fetchById(session.classId);

            // Schedule reminders
            await LocalNotificationService().scheduleClassReminders(
              classSessionId: session.id,
              className: classInfo.className,
              classStartTime: classStart,
            );

            scheduled++;
            _log(
              '✅ Scheduled notifications for: ${classInfo.className} (${session.id})',
            );
          } else {
            skipped++;
            _log('⏭️  Skipped past class: ${session.id}');
          }
        } catch (e) {
          _log(
            '❌ Failed to schedule for session ${enrollment.classSessionId}: $e',
          );
        }
      }

      _log('✨ Scheduling complete: $scheduled scheduled, $skipped skipped');
    } catch (e) {
      _log('❌ Error scheduling notifications: $e');
    }
  }

  /// Check for classes starting soon and show immediate notifications
  Future<void> checkClassesStartingSoon() async {
    try {
      final learnerId = await LocalStorage.getLearnerId();
      if (learnerId == null) return;

      final allEnrollments = await Enrollment.fetchAll();
      final activeEnrollments = allEnrollments
          .where(
            (e) =>
                e.learnerId == learnerId &&
                e.enrollmentStatus.toLowerCase() == 'active',
          )
          .toList();

      final now = DateTime.now();

      for (final enrollment in activeEnrollments) {
        try {
          final session = await ClassSession.fetchById(
            enrollment.classSessionId,
          );
          final classStart = DateTime.parse(session.classStart).toLocal();
          final minutesUntilStart = classStart.difference(now).inMinutes;

          // If class is starting within 5 minutes
          if (minutesUntilStart > 0 && minutesUntilStart <= 5) {
            final classInfo = await ClassInfo.fetchById(session.classId);

            await LocalNotificationService().showClassStartingNow(
              classSessionId: session.id,
              className: classInfo.className,
            );

            _log('🔥 Class starting soon: ${classInfo.className}');
          }
        } catch (e) {
          _log('Error checking class ${enrollment.classSessionId}: $e');
        }
      }
    } catch (e) {
      _log('Error checking classes starting soon: $e');
    }
  }

  /// Reschedule notifications after enrollment changes
  Future<void> rescheduleForLearner() async {
    _log('Rescheduling notifications...');
    await scheduleAllNotifications();
  }

  /// Cancel all notifications for a specific session
  Future<void> cancelForSession(int classSessionId) async {
    try {
      await LocalNotificationService().cancelClassReminders(classSessionId);
      _log('Cancelled notifications for session $classSessionId');
    } catch (e) {
      _log('Failed to cancel notifications for session $classSessionId: $e');
    }
  }
}
