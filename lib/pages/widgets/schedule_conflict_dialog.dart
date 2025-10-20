import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/class_sessions.dart';
import 'package:tutorium_frontend/util/schedule_validator.dart';

/// Dialog แสดงข้อมูล Schedule Conflict
class ScheduleConflictDialog extends StatelessWidget {
  final String message;
  final List<ClassSession>? conflictSessions;

  const ScheduleConflictDialog({
    super.key,
    required this.message,
    this.conflictSessions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text('เวลาทับกัน'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (conflictSessions != null && conflictSessions!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Class Sessions ที่ทับกัน:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...conflictSessions!.map(
                (session) => _buildConflictCard(session),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }

  Widget _buildConflictCard(ClassSession session) {
    final start = DateTime.parse(session.classStart);
    final end = DateTime.parse(session.classFinish);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.description,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${ScheduleValidator.formatDateTime(start)} - ${ScheduleValidator.formatDateTime(end)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// แสดง dialog
  static void show(
    BuildContext context, {
    required String message,
    List<ClassSession>? conflictSessions,
  }) {
    showDialog(
      context: context,
      builder: (context) => ScheduleConflictDialog(
        message: message,
        conflictSessions: conflictSessions,
      ),
    );
  }
}
