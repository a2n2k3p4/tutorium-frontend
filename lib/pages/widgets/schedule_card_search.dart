import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tutorium_frontend/pages/search/class_enroll.dart';
import 'package:tutorium_frontend/util/custom_cache_manager.dart';

class ScheduleCardSearch extends StatelessWidget {
  final int classId;
  final String className;
  final int? enrolledLearner; // Make optional
  final int? learnerLimit; // Make optional
  final String teacherName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? imageUrl;
  final String fallbackAsset;
  final double rating;
  final bool showSchedule;

  const ScheduleCardSearch({
    super.key,
    required this.classId,
    required this.className,
    this.enrolledLearner, // Optional
    this.learnerLimit, // Optional
    required this.teacherName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.imageUrl,
    this.fallbackAsset = 'assets/images/default.jpg',
    this.showSchedule = true,
    required this.rating,
  });

  String formatTime24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    // Show enrollment info only if data is available
    final showEnrollmentInfo =
        enrolledLearner != null && learnerLimit != null && learnerLimit! > 0;

    Widget buildImage() {
      final path = imageUrl;
      if (path != null && path.isNotEmpty) {
        if (path.startsWith('http')) {
          return CachedNetworkImage(
            imageUrl: path,
            fit: BoxFit.cover,
            cacheManager: ClassImageCacheManager(),
            fadeInDuration: const Duration(milliseconds: 300),
            fadeOutDuration: const Duration(milliseconds: 100),
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ),
            errorWidget: (context, url, error) =>
                Image.asset(fallbackAsset, fit: BoxFit.cover),
          );
        }
        return Image.asset(path, fit: BoxFit.cover);
      }

      return Image.asset(fallbackAsset, fit: BoxFit.cover);
    }

    // คำนวณเปอร์เซ็นต์ที่จองแล้ว (only if data available)
    final enrollmentPercentage =
        (showEnrollmentInfo && learnerLimit != null && learnerLimit! > 0)
        ? ((enrolledLearner! / learnerLimit!) * 100).clamp(0, 100)
        : 0.0;

    // คำนวณที่เหลือ
    final seatsRemaining = showEnrollmentInfo
        ? (learnerLimit! - enrolledLearner!).clamp(0, learnerLimit!)
        : 0;

    // กำหนดสีและข้อความตามสถานะ
    final bool isAlmostFull = showEnrollmentInfo && enrollmentPercentage >= 80;
    final bool isFull = showEnrollmentInfo && enrolledLearner! >= learnerLimit!;

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
            mainAxisSize: MainAxisSize.min,
            children: [
              // รูปภาพพร้อมป้ายสถานะ
              Stack(
                children: [
                  SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: buildImage(),
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
                              color: statusColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFull
                                  ? Icons.block
                                  : Icons.local_fire_department,
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
              Flexible(
                child: Padding(
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
                      if (showSchedule) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatTime24(startTime)} - ${formatTime24(endTime)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ] else
                        const SizedBox(height: 4),
                      Text(
                        'Teacher : $teacherName',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // ส่วนแสดงจำนวนผู้ลงทะเบียน (แสดงเฉพาะเมื่อมีข้อมูล)
                      if (showEnrollmentInfo) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 14,
                              color: Colors.grey[600],
                            ),
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
                              Flexible(
                                child: Text(
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
                                  overflow: TextOverflow.ellipsis,
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressColor,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
