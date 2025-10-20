import 'package:flutter/foundation.dart';

import 'class_sessions.dart' as class_sessions;
import 'enrollments.dart' as enrollments;
import 'learners.dart' as learners;
import 'notifications.dart' as notifications;

class ClassReadinessService {
  static const String statusScheduled = 'scheduled';
  static const String statusTeacherReady = 'teacher_ready';
  static const String statusLive = 'live';
  static const String statusCompleted = 'completed';

  static const List<String> _orderedStatuses = <String>[
    statusScheduled,
    statusTeacherReady,
    statusLive,
    statusCompleted,
  ];

  static String normalizeStatus(String? rawStatus) {
    final value = rawStatus?.trim().toLowerCase() ?? '';
    switch (value) {
      case 'teacher_ready':
      case 'ready':
      case 'teacherready':
        return statusTeacherReady;
      case 'live':
      case 'ongoing':
      case 'in_progress':
      case 'in-progress':
        return statusLive;
      case 'completed':
      case 'complete':
      case 'finished':
      case 'done':
        return statusCompleted;
      case 'scheduled':
      case 'pending':
      case 'upcoming':
        return statusScheduled;
      default:
        return value.isEmpty ? statusScheduled : value;
    }
  }

  static bool _shouldUpgrade(String current, String target) {
    final currentIndex = _orderedStatuses.indexOf(current);
    final targetIndex = _orderedStatuses.indexOf(target);
    if (targetIndex == -1) {
      return false;
    }
    if (currentIndex == -1) {
      return true;
    }
    return currentIndex < targetIndex;
  }

  static Future<class_sessions.ClassSession> markTeacherReady(
    class_sessions.ClassSession session,
  ) async {
    final current = normalizeStatus(session.classStatus);
    if (!_shouldUpgrade(current, statusTeacherReady)) {
      return session;
    }

    final updated = session.copyWith(
      classStatus: statusTeacherReady,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    debugPrint(
      '📚 [ClassReady] Marking session ${session.id} as teacher_ready',
    );
    return class_sessions.ClassSession.update(session.id, updated);
  }

  static Future<class_sessions.ClassSession> markClassLive(
    class_sessions.ClassSession session,
  ) async {
    final current = normalizeStatus(session.classStatus);
    if (!_shouldUpgrade(current, statusLive)) {
      return session;
    }

    final updated = session.copyWith(
      classStatus: statusLive,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    debugPrint('🎬 [ClassReady] Marking session ${session.id} as live');
    return class_sessions.ClassSession.update(session.id, updated);
  }

  static Future<class_sessions.ClassSession> markClassCompleted(
    class_sessions.ClassSession session,
  ) async {
    final current = normalizeStatus(session.classStatus);
    if (!_shouldUpgrade(current, statusCompleted)) {
      return session;
    }

    final updated = session.copyWith(
      classStatus: statusCompleted,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    debugPrint('✅ [ClassReady] Marking session ${session.id} as completed');
    return class_sessions.ClassSession.update(session.id, updated);
  }

  static Future<void> broadcastTeacherReady({
    required int classSessionId,
    required String className,
    required String teacherName,
  }) async {
    try {
      final enrollmentList = await enrollments.Enrollment.fetchAll(
        query: {'class_session_id': classSessionId},
      );

      if (enrollmentList.isEmpty) {
        debugPrint(
          'ℹ️  [ClassReady] No enrollments to notify for session $classSessionId',
        );
        return;
      }

      final learnerIds = enrollmentList
          .map((e) => e.learnerId)
          .where((id) => id != 0)
          .toSet();

      final now = DateTime.now().toUtc();
      final futures = <Future<void>>[];

      for (final learnerId in learnerIds) {
        futures.add(
          _notifyLearner(
            learnerId: learnerId,
            notificationDate: now,
            className: className,
            teacherName: teacherName,
            classSessionId: classSessionId,
          ),
        );
      }

      await Future.wait(futures);
      debugPrint(
        '📢 [ClassReady] Broadcast sent to ${learnerIds.length} learners',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [ClassReady] Failed to broadcast readiness: $e');
      debugPrint(stackTrace.toString());
    }
  }

  static Future<void> _notifyLearner({
    required int learnerId,
    required DateTime notificationDate,
    required String className,
    required String teacherName,
    required int classSessionId,
  }) async {
    try {
      final learner = await learners.Learner.fetchById(learnerId);
      if (learner.userId == 0) {
        debugPrint(
          '⚠️  [ClassReady] Learner $learnerId has no userId, skipping',
        );
        return;
      }

      final description =
          'คลาส "$className" พร้อมแล้วโดย $teacherName (Session $classSessionId)';

      await notifications.NotificationModel.create(
        notifications.NotificationModel(
          notificationDate: notificationDate,
          notificationDescription: description,
          notificationType: 'class_ready',
          readFlag: false,
          userId: learner.userId,
        ),
      );
    } catch (e) {
      debugPrint('❌ [ClassReady] Failed to notify learner $learnerId: $e');
    }
  }
}
