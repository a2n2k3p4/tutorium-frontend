import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/service/class_sessions.dart' as session_api;
import 'package:tutorium_frontend/service/classes.dart' as class_api;
import 'package:tutorium_frontend/service/enrollments.dart' as enrollment_api;

/// Utilities for stitching together class, session, and enrollment data so we
/// can present accurate learner counts across the app. The helper keeps the
/// workflow in one place and adds consistent debug logging for easier tracing.
class ClassEnrollmentPipeline {
  const ClassEnrollmentPipeline._();

  /// Build a map of `classId -> active enrollment count`.
  static Future<Map<int, int>> aggregateActiveEnrollments(
    List<class_api.ClassInfo> classes,
  ) async {
    final classIds = classes.map((cls) => cls.id).where((id) => id > 0).toSet();
    if (classIds.isEmpty) {
      debugPrint('👥 Enrollment: no classes to process');
      return {};
    }

    try {
      debugPrint(
        '👥 Enrollment: fetching sessions for class IDs ${classIds.join(', ')}',
      );
      final sessions = await session_api.ClassSession.fetchAll(
        query: {'class_ids': classIds.join(',')},
      );

      if (sessions.isEmpty) {
        debugPrint('👥 Enrollment: backend returned 0 sessions');
        return {for (final classId in classIds) classId: 0};
      }

      final sessionToClass = <int, int>{};
      for (final session in sessions) {
        if (session.id <= 0) continue;
        sessionToClass[session.id] = session.classId;
      }

      if (sessionToClass.isEmpty) {
        debugPrint('👥 Enrollment: no session IDs to query enrollments with');
        return {for (final classId in classIds) classId: 0};
      }

      final sessionIds = sessionToClass.keys.join(',');
      debugPrint(
        '👥 Enrollment: fetching enrollments for session IDs $sessionIds',
      );
      final enrollments = await enrollment_api.Enrollment.fetchAll(
        query: {'session_ids': sessionIds},
      );

      final counts = {for (final classId in classIds) classId: 0};
      for (final enrollment in enrollments) {
        if (enrollment.enrollmentStatus.toLowerCase() != 'active') {
          continue;
        }
        final classId = sessionToClass[enrollment.classSessionId];
        if (classId == null) {
          debugPrint(
            '👥 Enrollment: session ${enrollment.classSessionId} missing class mapping',
          );
          continue;
        }
        counts[classId] = (counts[classId] ?? 0) + 1;
      }

      debugPrint('👥 Enrollment: aggregated counts $counts');
      return counts;
    } catch (e, stack) {
      debugPrint('❌ Enrollment: pipeline failed - $e');
      debugPrint('$stack');
      return {for (final classId in classIds) classId: 0};
    }
  }
}
