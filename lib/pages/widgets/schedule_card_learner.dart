import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tutorium_frontend/pages/learn/learn.dart';
import 'package:tutorium_frontend/pages/learn/class_detail_page.dart';
import 'package:tutorium_frontend/util/custom_cache_manager.dart';

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
  final VoidCallback? onCancel;
  final bool canCancel;

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
    this.onCancel,
    this.canCancel = false,
  });

  String formatTime24(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;

    // Responsive image dimensions
    final imageWidth = isSmallScreen
        ? 90.0
        : isMediumScreen
        ? 100.0
        : 110.0;
    final imageHeight = isSmallScreen
        ? 120.0
        : isMediumScreen
        ? 130.0
        : 140.0;

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
      onTap: () async {
        // Check if user has viewed class details before
        final hasViewed = await ClassDetailPage.hasViewed(classSessionId);

        if (!context.mounted) return;

        if (hasViewed) {
          // Go directly to LearnPage if already viewed
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
        } else {
          // Show ClassDetailPage first
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassDetailPage(
                classSessionId: classSessionId,
                className: className,
                teacherName: teacherName,
                jitsiMeetingUrl: classUrl,
                isTeacher: isTeacher,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
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
                  child: _buildImage(imageWidth, imageHeight),
                ),
                SizedBox(width: isSmallScreen ? 8 : 16),
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 8 : 12,
                      horizontal: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Class name
                        Text(
                          className,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 15.0 : 18.0,
                            fontWeight: FontWeight.w600,
                            color: isPast ? Colors.grey[600] : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isSmallScreen ? 6 : 8),
                        // Date and time
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: isSmallScreen ? 12 : 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Expanded(
                              child: Text(
                                '${date.day}/${date.month}/${date.year}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11.0 : 13.0,
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
                              size: isSmallScreen ? 12 : 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Text(
                              '${formatTime24(startTime)} - ${formatTime24(endTime)}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11.0 : 13.0,
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
                              size: isSmallScreen ? 12 : 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Expanded(
                              child: Text(
                                teacherName,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11.0 : 13.0,
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
                              size: isSmallScreen ? 12 : 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Text(
                              '$enrolledLearner ผู้เรียน',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11.0 : 13.0,
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
                  padding: EdgeInsets.all(isSmallScreen ? 8.0 : 12.0),
                  child: Column(
                    children: [
                      if (isHappeningNow)
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: isSmallScreen ? 22 : 28,
                          ),
                        )
                      else if (isPast)
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.grey[600],
                            size: isSmallScreen ? 22 : 28,
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.schedule,
                            color: Colors.amber,
                            size: isSmallScreen ? 22 : 28,
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
            // Cancel button for upcoming classes
            if (!isHappeningNow && !isPast && onCancel != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: TextButton.icon(
                  onPressed: canCancel ? onCancel : null,
                  icon: Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: canCancel ? Colors.red : Colors.grey,
                  ),
                  label: Text(
                    canCancel
                        ? 'คลาสยังไม่เริ่ม'
                        : 'ไม่สามารถยกเลิกได้ (คลาสใกล้เริ่มแล้ว)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: canCancel ? Colors.red : Colors.grey,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: canCancel
                        ? Colors.red[50]
                        : Colors.grey[100],
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(double width, double height) {
    const fallback = 'assets/images/guitar.jpg';

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
      return CachedNetworkImage(
        imageUrl: imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheManager: ClassImageCacheManager(),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            _fallbackImage(width, height, fallback),
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
