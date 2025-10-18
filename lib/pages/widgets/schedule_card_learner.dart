import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/learn/learn.dart';

class ScheduleCardLearner extends StatelessWidget {
  final String className;
  final int enrolledLearner;
  final String teacherName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String imagePath;
  final int classSessionId;
  final String classUrl;
  final bool isTeacher;

  const ScheduleCardLearner({
    super.key,
    required this.className,
    required this.enrolledLearner,
    required this.teacherName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.imagePath,
    required this.classSessionId,
    required this.classUrl,
    this.isTeacher = false,
  });

  String formatTime24(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    // Check if class is happening now
    final now = DateTime.now();
    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    final endDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );
    final isHappeningNow =
        now.isAfter(startDateTime) && now.isBefore(endDateTime);
    final isPast = now.isAfter(endDateTime);

    return GestureDetector(
      onTap: () {
        // Navigate to LearnPage when card is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LearnPage(
              classSessionId: classSessionId,
              className: className,
              teacherName: teacherName,
              jitsiMeetingUrl: classUrl,
              isTeacher: isTeacher,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: isHappeningNow
              ? Border.all(color: Colors.green, width: 2)
              : isPast
              ? Border.all(color: Colors.grey[300]!, width: 1)
              : null,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: _buildImage(),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Class name
                        Text(
                          className,
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w600,
                            color: isPast ? Colors.grey[600] : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Date and time
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${date.day}/${date.month}/${date.year}',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${formatTime24(startTime)} - ${formatTime24(endTime)}',
                              style: TextStyle(
                                fontSize: 13.0,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Teacher
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                teacherName,
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: Colors.grey[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Enrolled learners
                        Row(
                          children: [
                            Icon(
                              Icons.group,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$enrolledLearner ผู้เรียน',
                              style: TextStyle(
                                fontSize: 13.0,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Status indicator
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      if (isHappeningNow)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        )
                      else if (isPast)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.grey[600],
                            size: 28,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.schedule,
                            color: Colors.amber,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Status badge at bottom
            if (isHappeningNow || isPast)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isHappeningNow ? Colors.green[50] : Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  isHappeningNow ? '🔴 กำลังเรียนอยู่' : '✅ เรียนเสร็จแล้ว',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isHappeningNow
                        ? Colors.green[700]
                        : Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    const fallback = 'assets/images/guitar.jpg';
    final width = 110.0;
    final height = 140.0;

    if (imagePath.toLowerCase().startsWith('data:image')) {
      try {
        final payload = imagePath.substring(imagePath.indexOf(',') + 1);
        final bytes = base64Decode(payload);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackImage(width, height, fallback),
        );
      } catch (e) {
        debugPrint('⚠️ Failed to decode base64 class image: $e');
      }
    }

    if (imagePath.toLowerCase().startsWith('http')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackImage(width, height, fallback),
      );
    }

    final assetPath = imagePath.isNotEmpty ? imagePath : fallback;
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackImage(width, height, fallback),
    );
  }

  Widget _fallbackImage(double width, double height, String asset) {
    return Image.asset(asset, width: width, height: height, fit: BoxFit.cover);
  }
}
