import 'package:flutter/material.dart';

class ScheduleCard extends StatelessWidget {
  final String className;
  final int enrolledLearner;
  final String teacherName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String imagePath;

  const ScheduleCard({
    Key? key,
    required this.className,
    required this.enrolledLearner,
    required this.teacherName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.imagePath,
  }) : super(key: key);

  String formatTime24(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
            child: Image.asset(
              imagePath,
              width: 120,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  className,
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year} | ${formatTime24(startTime)} - ${formatTime24(endTime)}',
                  style: const TextStyle(fontSize: 13.0),
                ),
                Text(
                  'Enrolled Learner : $enrolledLearner',
                  style: const TextStyle(fontSize: 13.0),
                ),
                Text(
                  'Teacher : $teacherName',
                  style: const TextStyle(fontSize: 13.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
