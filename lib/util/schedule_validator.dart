import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/models/class_models.dart' as models;
import 'package:tutorium_frontend/service/class_sessions.dart'
    as class_sessions;
import 'package:tutorium_frontend/service/enrollments.dart' as enrollment_api;
import 'package:tutorium_frontend/service/classes.dart' as classes_api;

/// ตรวจสอบและป้องกันการลงเวลาทับกันของ Class Sessions
/// สำหรับทั้ง Teacher และ Learner
class ScheduleValidator {
  /// ตรวจสอบว่าช่วงเวลาทับกันหรือไม่
  /// Returns true ถ้าทับกัน
  static bool isTimeOverlapping(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    // ทับกันถ้า:
    // - start1 < end2 AND end1 > start2
    // หรือพูดง่ายๆคือ ถ้าจุดเริ่มต้นของช่วงหนึ่งอยู่ก่อนจุดสิ้นสุดของอีกช่วงหนึ่ง
    // และจุดสิ้นสุดของช่วงหนึ่งอยู่หลังจุดเริ่มต้นของอีกช่วงหนึ่ง
    return start1.isBefore(end2) && end1.isAfter(start2);
  }

  /// ตรวจสอบว่าช่วงเวลาทับกันหรือไม่ (รวมถึงเวลาเท่ากัน)
  /// Returns true ถ้าทับกันหรือเวลาเท่ากัน
  static bool isTimeOverlappingStrict(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    // ทับกันถ้า:
    // - start1 <= end2 AND end1 >= start2
    // ห้ามแม้แต่เวลาเดียว
    return start1.isBefore(end2.add(const Duration(seconds: 1))) &&
        end1.isAfter(start2.subtract(const Duration(seconds: 1)));
  }

  /// Find the first conflicting session from an in-memory list.
  static models.ClassSession? findConflict(
    DateTime newStart,
    DateTime newEnd,
    List<models.ClassSession> sessions,
  ) {
    for (final session in sessions) {
      if (isTimeOverlappingStrict(
        newStart,
        newEnd,
        session.classStart,
        session.classFinish,
      )) {
        return session;
      }
    }
    return null;
  }

  /// ตรวจสอบว่า Teacher มี Class Session ทับกันหรือไม่
  /// Returns a map with keys 'valid', 'message', และ 'conflictSessions' (รายการของ ClassSession)
  static Future<Map<String, dynamic>> validateTeacherSchedule({
    required int teacherId,
    required DateTime newStart,
    required DateTime newEnd,
    int? excludeSessionId, // ใช้ตอน update session เพื่อไม่ให้เช็คกับตัวเอง
  }) async {
    try {
      // ดึง Classes ทั้งหมดของ Teacher ก่อน
      final teacherClasses = await classes_api.ClassInfo.fetchByTeacher(
        teacherId,
      );

      if (teacherClasses.isEmpty) {
        // ถ้าไม่มี class ก็ไม่มีปัญหาเวลาทับ
        return {'valid': true, 'message': null, 'conflictSessions': null};
      }

      // ดึง Class Sessions ทั้งหมดของแต่ละ Class
      final allSessions = <class_sessions.ClassSession>[];
      for (final teacherClass in teacherClasses) {
        try {
          final sessions = await class_sessions.ClassSession.fetchAll(
            query: {'class_id': teacherClass.id},
          );
          allSessions.addAll(sessions);
        } catch (e) {
          debugPrint(
            '⚠️ Failed to fetch sessions for class ${teacherClass.id}: $e',
          );
          // Continue checking other classes even if one fails
          continue;
        }
      }

      // กรอง session ที่ต้องการไม่เช็ค และเฉพาะที่ยังไม่จบ
      final sessionsToCheck = allSessions.where((s) {
        if (excludeSessionId != null && s.id == excludeSessionId) {
          return false;
        }
        // เช็คเฉพาะ session ที่ยังไม่จบ (scheduled, ongoing)
        final status = s.classStatus.toLowerCase();
        return status == 'scheduled' || status == 'ongoing';
      }).toList();

      // ตรวจสอบทีละ session
      final conflictSessions = <class_sessions.ClassSession>[];
      for (final session in sessionsToCheck) {
        try {
          final sessionStart = DateTime.parse(session.classStart);
          final sessionEnd = DateTime.parse(session.classFinish);

          // ใช้ strict mode ห้ามทับแม้แต่เวลาเดียว
          if (isTimeOverlappingStrict(
            newStart,
            newEnd,
            sessionStart,
            sessionEnd,
          )) {
            conflictSessions.add(session);
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse time for session ${session.id}: $e');
          // Continue checking other sessions
          continue;
        }
      }

      if (conflictSessions.isNotEmpty) {
        return {
          'valid': false,
          'message':
              'พบ Class Session ทับกัน ${conflictSessions.length} รายการ',
          'conflictSessions': conflictSessions,
        };
      }

      return {'valid': true, 'message': null, 'conflictSessions': null};
    } catch (e) {
      debugPrint('❌ Error in validateTeacherSchedule: $e');
      // ถ้า error ให้ return valid: true เพื่อไม่บล็อก user
      // แต่ควร log error ไว้ตรวจสอบ
      return {'valid': true, 'message': null, 'conflictSessions': null};
    }
  }

  /// ตรวจสอบว่า Learner มี Enrollment ทับกันหรือไม่
  /// Returns a map with keys 'valid', 'message', และ 'conflictSessions' (รายการของ ClassSession)
  static Future<Map<String, dynamic>> validateLearnerSchedule({
    required int learnerId,
    required DateTime newStart,
    required DateTime newEnd,
    int? excludeSessionId, // ใช้ตอนยกเลิก enrollment
  }) async {
    try {
      // ดึง Enrollments ทั้งหมดของ Learner
      final enrollments = await enrollment_api.Enrollment.fetchAll(
        query: {'learner_id': learnerId},
      );

      // กรองเฉพาะ enrollment ที่ active หรือ pending
      final activeEnrollments = enrollments.where((e) {
        final status = e.enrollmentStatus.toLowerCase();
        return status == 'active' || status == 'pending';
      }).toList();

      if (activeEnrollments.isEmpty) {
        // ถ้าไม่มี enrollment ก็ไม่มีปัญหาเวลาทับ
        return {'valid': true, 'message': null, 'conflictSessions': null};
      }

      // ดึง Class Sessions ที่เกี่ยวข้อง
      final conflictSessions = <class_sessions.ClassSession>[];
      for (final enrollment in activeEnrollments) {
        // ข้ามถ้าเป็น session ที่ต้องการไม่เช็ค
        if (excludeSessionId != null &&
            enrollment.classSessionId == excludeSessionId) {
          continue;
        }

        try {
          final session = await class_sessions.ClassSession.fetchById(
            enrollment.classSessionId,
          );

          try {
            final sessionStart = DateTime.parse(session.classStart);
            final sessionEnd = DateTime.parse(session.classFinish);

            // ใช้ strict mode ห้ามทับแม้แต่เวลาเดียว
            if (isTimeOverlappingStrict(
              newStart,
              newEnd,
              sessionStart,
              sessionEnd,
            )) {
              conflictSessions.add(session);
            }
          } catch (e) {
            debugPrint('⚠️ Failed to parse time for session ${session.id}: $e');
            // Continue checking other sessions
            continue;
          }
        } catch (e) {
          debugPrint(
            '⚠️ Failed to fetch session ${enrollment.classSessionId}: $e',
          );
          // Continue checking other enrollments
          continue;
        }
      }

      if (conflictSessions.isNotEmpty) {
        return {
          'valid': false,
          'message':
              'คุณมี Class Session ทับกันอยู่ ${conflictSessions.length} รายการ',
          'conflictSessions': conflictSessions,
        };
      }

      return {'valid': true, 'message': null, 'conflictSessions': null};
    } catch (e) {
      debugPrint('❌ Error in validateLearnerSchedule: $e');
      // ถ้า error ให้ return valid: true เพื่อไม่บล็อก user
      // แต่ควร log error ไว้ตรวจสอบ
      return {'valid': true, 'message': null, 'conflictSessions': null};
    }
  }

  /// ตรวจสอบ Schedule ก่อน Create Class Session (Teacher)
  static Future<Map<String, dynamic>> validateBeforeCreateSession({
    required int teacherId,
    required DateTime classStart,
    required DateTime classFinish,
  }) async {
    // ตรวจสอบว่าเวลาเริ่ม < เวลาจบ
    if (!classStart.isBefore(classFinish)) {
      return {
        'valid': false,
        'message': 'เวลาเริ่มต้องมาก่อนเวลาจบ',
        'conflictSessions': null,
      };
    }

    // ตรวจสอบว่าไม่ทับกับ session อื่นของ teacher
    return await validateTeacherSchedule(
      teacherId: teacherId,
      newStart: classStart,
      newEnd: classFinish,
    );
  }

  /// ตรวจสอบ Schedule ก่อน Enroll (Learner)
  static Future<Map<String, dynamic>> validateBeforeEnroll({
    required int learnerId,
    required int sessionId,
  }) async {
    try {
      // ดึงข้อมูล session ที่จะ enroll
      final session = await class_sessions.ClassSession.fetchById(sessionId);

      try {
        final sessionStart = DateTime.parse(session.classStart);
        final sessionEnd = DateTime.parse(session.classFinish);

        // ตรวจสอบว่าไม่ทับกับ enrollment อื่นของ learner
        return await validateLearnerSchedule(
          learnerId: learnerId,
          newStart: sessionStart,
          newEnd: sessionEnd,
          excludeSessionId: sessionId,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to parse session time: $e');
        // ถ้า parse time ไม่ได้ ให้ผ่าน (ไม่บล็อก)
        return {'valid': true, 'message': null, 'conflictSessions': null};
      }
    } catch (e) {
      debugPrint('❌ Error in validateBeforeEnroll: $e');
      // ถ้า error ให้ return valid: true เพื่อไม่บล็อก user
      return {'valid': true, 'message': null, 'conflictSessions': null};
    }
  }

  /// ตรวจสอบ Schedule ก่อน Update Class Session (Teacher)
  static Future<Map<String, dynamic>> validateBeforeUpdateSession({
    required int teacherId,
    required int sessionId,
    required DateTime classStart,
    required DateTime classFinish,
  }) async {
    // ตรวจสอบว่าเวลาเริ่ม < เวลาจบ
    if (!classStart.isBefore(classFinish)) {
      return {
        'valid': false,
        'message': 'เวลาเริ่มต้องมาก่อนเวลาจบ',
        'conflictSessions': null,
      };
    }

    // ตรวจสอบว่าไม่ทับกับ session อื่นของ teacher (ยกเว้นตัวเอง)
    return await validateTeacherSchedule(
      teacherId: teacherId,
      newStart: classStart,
      newEnd: classFinish,
      excludeSessionId: sessionId,
    );
  }

  /// สร้างข้อความแสดง conflict sessions
  static String formatConflictMessage(
    List<class_sessions.ClassSession> conflicts,
  ) {
    if (conflicts.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('พบ Class Session ทับกัน:');
    for (var i = 0; i < conflicts.length; i++) {
      final session = conflicts[i];
      final start = DateTime.parse(session.classStart);
      final end = DateTime.parse(session.classFinish);
      buffer.writeln(
        '${i + 1}. ${session.description} (${_formatDateTime(start)} - ${_formatDateTime(end)})',
      );
    }
    return buffer.toString();
  }

  /// Format DateTime เป็น String แบบอ่านง่าย (สำหรับใช้ใน UI)
  static String formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Format DateTime เป็น String แบบอ่านง่าย (private)
  static String _formatDateTime(DateTime dt) {
    return formatDateTime(dt);
  }
}
