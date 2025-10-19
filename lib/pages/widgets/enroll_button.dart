import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/ClassSessions.dart';
import 'package:tutorium_frontend/service/Enrollments.dart';
import 'package:tutorium_frontend/util/schedule_validator.dart';
import 'package:tutorium_frontend/pages/widgets/schedule_conflict_dialog.dart';

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

  Future<void> _handleEnroll() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. ตรวจสอบเวลาทับกันก่อน
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

      // 2. แสดง confirmation dialog
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

      // 3. สร้าง enrollment
      final enrollment = Enrollment(
        classSessionId: widget.sessionId,
        enrollmentStatus: 'active',
        learnerId: widget.learnerId,
      );

      await Enrollment.create(enrollment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลงทะเบียนสำเร็จ!'),
            backgroundColor: Colors.green,
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
                  Icons.deadline,
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
                  'รับ ${session.learnerLimit} คน',
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
