import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/class_sessions.dart';
import 'package:tutorium_frontend/service/enrollments.dart';
import 'package:tutorium_frontend/util/schedule_validator.dart';
import 'package:tutorium_frontend/pages/widgets/schedule_conflict_dialog.dart';
import 'package:tutorium_frontend/services/local_notification_service.dart';
import 'package:tutorium_frontend/service/classes.dart';
import 'package:tutorium_frontend/service/users.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

/// ปุ่ม Enroll พร้อมตรวจสอบเวลาทับกัน
class EnrollButton extends StatefulWidget {
  final int sessionId;
  final int learnerId;
  final Function()? onEnrollSuccess;

  const EnrollButton({
    super.key,
    required this.sessionId,
    required this.learnerId,
    this.onEnrollSuccess,
  });

  @override
  State<EnrollButton> createState() => _EnrollButtonState();
}

class _EnrollButtonState extends State<EnrollButton> {
  bool _isLoading = false;

  Future<int> _getCurrentUserId() async {
    final userId = await LocalStorage.getUserId();
    if (userId == null) {
      throw Exception('Unable to get current user ID');
    }
    return userId;
  }

  Future<void> _handleEnroll() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 0. ตรวจสอบว่าผู้ใช้เป็น teacher ของคลาสนี้หรือไม่
      final session = await ClassSession.fetchById(widget.sessionId);
      final classInfo = await ClassInfo.fetchById(session.classId);

      // ดึงข้อมูล current user เพื่อเช็ค teacher ID
      final currentUser = await User.fetchById(await _getCurrentUserId());
      if (currentUser.teacher != null &&
          currentUser.teacher!.id == classInfo.teacherId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ครูไม่สามารถลงทะเบียนคลาสของตัวเองได้'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 1. ตรวจสอบว่าลงทะเบียนซ้ำหรือไม่
      final existingEnrollments = await Enrollment.fetchAll(
        query: {
          'learner_id': widget.learnerId,
          'class_session_id': widget.sessionId,
        },
      );

      if (existingEnrollments.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('คุณลงทะเบียนคลาสนี้แล้ว'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. ตรวจสอบว่าคลาสเต็มหรือไม่ (จำกัดไม่เกิน 20 คน)
      final enrollments = await Enrollment.fetchAll(
        query: {'class_session_id': widget.sessionId},
      );
      final currentEnrollmentCount = enrollments
          .where((e) => e.enrollmentStatus == 'active')
          .length;

      // Enforce maximum of 20 participants per session
      const maxParticipants = 20;
      final effectiveLimit = session.learnerLimit > maxParticipants
          ? maxParticipants
          : session.learnerLimit;

      if (currentEnrollmentCount >= effectiveLimit) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ขอโทษ คลาสนี้เต็มแล้ว (รับได้สูงสุด $effectiveLimit คน)',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 3. ตรวจสอบเวลาทับกันก่อน
      final validationResult = await ScheduleValidator.validateBeforeEnroll(
        learnerId: widget.learnerId,
        sessionId: widget.sessionId,
      );

      if (!validationResult['valid']) {
        // แสดง dialog เวลาทับกัน
        if (mounted) {
          ScheduleConflictDialog.show(
            context,
            message: validationResult['message'] ?? 'พบเวลาทับกัน',
            conflictSessions: validationResult['conflictSessions'],
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 4. แสดง confirmation dialog
      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันการลงทะเบียน'),
            content: const Text('คุณต้องการลงทะเบียนคลาสนี้หรือไม่?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('ยืนยัน'),
              ),
            ],
          ),
        );

        if (confirmed != true) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // 5. สร้าง enrollment
      final enrollment = Enrollment(
        classSessionId: widget.sessionId,
        enrollmentStatus: 'active',
        learnerId: widget.learnerId,
      );

      await Enrollment.create(enrollment);

      // 6. ดึงข้อมูล session และ class เพื่อ schedule notification
      try {
        final session = await ClassSession.fetchById(widget.sessionId);
        final classInfo = await ClassInfo.fetchById(session.classId);

        // Schedule class reminders
        await LocalNotificationService().scheduleClassReminders(
          classSessionId: widget.sessionId,
          className: classInfo.className,
          classStartTime: DateTime.parse(session.classStart).toLocal(),
        );

        // Show enrollment success notification
        await LocalNotificationService().showEnrollmentSuccess(
          className: classInfo.className,
          classStartTime: DateTime.parse(session.classStart).toLocal(),
        );

        debugPrint(
          '✅ [Enrollment] Scheduled notifications for ${classInfo.className}',
        );
      } catch (e) {
        debugPrint('⚠️ [Enrollment] Failed to schedule notifications: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ลงทะเบียนสำเร็จ! 🎉 คุณจะได้รับการแจ้งเตือนก่อนเรียน',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        widget.onEnrollSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleEnroll,
      icon: _isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.app_registration),
      label: Text(_isLoading ? 'กำลังตรวจสอบ...' : 'ลงทะเบียน'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}

/// Widget แสดงรายละเอียด Class Session พร้อมปุ่ม Enroll
class ClassSessionCard extends StatelessWidget {
  final ClassSession session;
  final int learnerId;
  final Function()? onEnrollSuccess;

  const ClassSessionCard({
    super.key,
    required this.session,
    required this.learnerId,
    this.onEnrollSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(session.classStart);
    final end = DateTime.parse(session.classFinish);
    final deadline = DateTime.parse(session.enrollmentDeadline);
    final now = DateTime.now();
    final isExpired = now.isAfter(deadline);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              session.description,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Time
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${ScheduleValidator.formatDateTime(start)} - ${ScheduleValidator.formatDateTime(end)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Enrollment Deadline
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isExpired ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  'ปิดรับสมัคร: ${ScheduleValidator.formatDateTime(deadline)}',
                  style: TextStyle(
                    color: isExpired ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Price & Limit
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16, color: Colors.green),
                Text(
                  '฿${session.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.people, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'รับ ${session.learnerLimit > 20 ? 20 : session.learnerLimit} คน',
                  style: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Enroll Button
            if (!isExpired)
              Center(
                child: EnrollButton(
                  sessionId: session.id,
                  learnerId: learnerId,
                  onEnrollSuccess: onEnrollSuccess,
                ),
              )
            else
              const Center(
                child: Text(
                  'หมดเวลาลงทะเบียน',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
