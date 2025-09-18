import 'package:flutter/material.dart';

class ScheduleCard_search extends StatelessWidget {
  final String className;
  final int enrolledLearner;
  final String teacherName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String imagePath;

  const ScheduleCard_search({
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
    return SizedBox(
      width: 180,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    className,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(fontSize: 12.0, color: Colors.grey),
                  ),
                  Text(
                    '${formatTime24(startTime)} - ${formatTime24(endTime)}',
                    style: const TextStyle(fontSize: 12.0, color: Colors.grey),
                  ),
                  Text(
                    'Enrolled Learner : $enrolledLearner learners',
                    style: const TextStyle(fontSize: 12.0),
                  ),
                  Text(
                    'Teacher : $teacherName',
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
