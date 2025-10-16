import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/search/class_enroll.dart';

class ScheduleCard_search extends StatelessWidget {
  final int classId;
  final String className;
  final int enrolledLearner;
  final String teacherName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String imagePath;
  final double rating;

  const ScheduleCard_search({
    super.key,
    required this.classId,
    required this.className,
    required this.enrolledLearner,
    required this.teacherName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.imagePath,
    required this.rating,
  });

  String formatTime24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassEnrollPage(
                classId: classId,
                teacherName: teacherName,
                rating: rating,
              ),
            ),
          );
        },
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 90,
                width: double.infinity,
                child: Image.asset(imagePath, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            className,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Teacher : $teacherName',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
