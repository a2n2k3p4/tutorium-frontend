import 'package:flutter/material.dart';

class ScheduleCard_search extends StatelessWidget {
  final String className;
  final int enrolledLearner;
  final int learnerLimit;
  final String teacherName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String imagePath;

  const ScheduleCard_search({
    Key? key,
    required this.className,
    required this.enrolledLearner,
    required this.learnerLimit,
    required this.teacherName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.imagePath,
  }) : super(key: key);

  String formatTime24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณเปอร์เซ็นต์ที่จองแล้ว
    final enrollmentPercentage = learnerLimit > 0
        ? (enrolledLearner / learnerLimit * 100).clamp(0, 100)
        : 0.0;

    // คำนวณที่เหลือ
    final seatsRemaining = (learnerLimit - enrolledLearner).clamp(
      0,
      learnerLimit,
    );

    // กำหนดสีและข้อความตามสถานะ
    final bool isAlmostFull = enrollmentPercentage >= 80;
    final bool isFull = enrolledLearner >= learnerLimit;

    Color progressColor;
    String statusText;
    Color statusColor;

    if (isFull) {
      progressColor = Colors.red;
      statusText = 'เต็มแล้ว!';
      statusColor = Colors.red;
    } else if (isAlmostFull) {
      progressColor = Colors.orange;
      statusText = 'เหลือที่น้อย!';
      statusColor = Colors.orange;
    } else {
      progressColor = Colors.green;
      statusText = '';
      statusColor = Colors.green;
    }

    return SizedBox(
      width: 180,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // รูปภาพพร้อมป้ายสถานะ
            Stack(
              children: [
                SizedBox(
                  height: 90,
                  width: double.infinity,
                  child: Image.asset(imagePath, fit: BoxFit.cover),
                ),
                // ป้ายแจ้งเตือน
                if (statusText.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFull ? Icons.block : Icons.local_fire_department,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    className,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${formatTime24(startTime)} - ${formatTime24(endTime)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Teacher : $teacherName',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // ส่วนแสดงจำนวนผู้ลงทะเบียน
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$enrolledLearner/$learnerLimit คน',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: progressColor,
                        ),
                      ),
                      const Spacer(),
                      if (!isFull)
                        Text(
                          'เหลือ $seatsRemaining ที่',
                          style: TextStyle(
                            fontSize: 10,
                            color: isAlmostFull
                                ? Colors.orange
                                : Colors.grey[600],
                            fontWeight: isAlmostFull
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: enrollmentPercentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 6,
                    ),
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
