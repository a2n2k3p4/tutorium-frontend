import 'package:tutorium_frontend/service/api_client.dart';
import 'package:tutorium_frontend/service/class_sessions.dart';
import 'package:tutorium_frontend/service/enrollments.dart';
import 'package:tutorium_frontend/service/reviews.dart';
import 'package:tutorium_frontend/service/classes.dart';

/// Model for class session that needs review
class PendingReviewClass {
  final int classId;
  final int classSessionId;
  final String className;
  final String classDescription;
  final DateTime classFinish;
  final String? bannerPictureUrl;

  const PendingReviewClass({
    required this.classId,
    required this.classSessionId,
    required this.className,
    required this.classDescription,
    required this.classFinish,
    this.bannerPictureUrl,
  });

  factory PendingReviewClass.fromJson(Map<String, dynamic> json) {
    return PendingReviewClass(
      classId: json['class_id'] ?? 0,
      classSessionId: json['class_session_id'] ?? 0,
      className: json['class_name'] ?? '',
      classDescription: json['class_description'] ?? '',
      classFinish: DateTime.parse(json['class_finish']),
      bannerPictureUrl: json['banner_picture_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'class_session_id': classSessionId,
      'class_name': className,
      'class_description': classDescription,
      'class_finish': classFinish.toIso8601String(),
      'banner_picture_url': bannerPictureUrl,
    };
  }
}

class PendingReviewService {
  /// Check if learner has pending reviews
  static Future<List<PendingReviewClass>> getPendingReviews(
    int learnerId,
  ) async {
    try {
      // Get all enrollments for this learner
      final enrollments = await Enrollment.fetchAll(
        query: {'learner_id': learnerId},
      );

      // Get all reviews by this learner
      final reviews = await Review.fetchAll(query: {'learner_id': learnerId});
      final reviewedClassIds = reviews.map((r) => r.classId).toSet();

      final pendingClasses = <PendingReviewClass>[];
      final now = DateTime.now();

      for (final enrollment in enrollments) {
        // Skip if enrollment is not active/completed
        if (enrollment.enrollmentStatus != 'active' &&
            enrollment.enrollmentStatus != 'completed') {
          continue;
        }

        try {
          // Get session details
          final session = await ClassSession.fetchById(
            enrollment.classSessionId,
          );

          // Parse session finish time
          final classFinish = DateTime.parse(session.classFinish);

          // Check if class has finished (more than 30 minutes ago)
          if (classFinish.isBefore(now.subtract(const Duration(minutes: 30)))) {
            // Check if class has been reviewed
            if (!reviewedClassIds.contains(session.classId)) {
              // Get class details
              try {
                final classInfo = await ClassInfo.fetchById(session.classId);
                pendingClasses.add(
                  PendingReviewClass(
                    classId: classInfo.id,
                    classSessionId: session.id,
                    className: classInfo.className,
                    classDescription: classInfo.classDescription,
                    classFinish: classFinish,
                    bannerPictureUrl: classInfo.bannerPictureUrl,
                  ),
                );
              } catch (_) {
                // Skip if class details cannot be fetched
              }
            }
          }
        } catch (_) {
          // Skip if session details cannot be fetched
          continue;
        }
      }

      // Sort by finish time (oldest first)
      pendingClasses.sort((a, b) => a.classFinish.compareTo(b.classFinish));

      return pendingClasses;
    } on ApiException catch (e) {
      throw Exception('Failed to get pending reviews: ${e.body}');
    } catch (e) {
      throw Exception('Failed to get pending reviews: $e');
    }
  }

  /// Check if learner has any pending reviews (quick check)
  static Future<bool> hasPendingReviews(int learnerId) async {
    try {
      final pending = await getPendingReviews(learnerId);
      return pending.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Submit a review for a class
  static Future<Review> submitReview({
    required int classId,
    required int learnerId,
    required int rating,
    required String comment,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      final review = Review(
        classId: classId,
        learnerId: learnerId,
        rating: rating,
        comment: comment.trim(),
      );

      return await Review.create(review);
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw Exception('Invalid review data: ${e.body}');
      } else if (e.statusCode == 500) {
        throw Exception('Failed to submit review. Please try again.');
      }
      rethrow;
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }
}
