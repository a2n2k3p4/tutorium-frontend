import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/pending_review_service.dart';
import 'package:tutorium_frontend/pages/widgets/mandatory_review_dialog.dart';

/// Guard to check if user has pending reviews before allowing navigation
class ReviewGuard {
  static int? _currentLearnerId;
  static bool _isChecking = false;

  /// Set the current learner ID for review checks
  static void setLearnerId(int? learnerId) {
    _currentLearnerId = learnerId;
  }

  /// Check if learner has pending reviews and show dialog if needed
  /// Returns true if navigation should proceed, false if blocked by pending review
  static Future<bool> checkAndShowReviewDialog(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_currentLearnerId == null) {
      return true; // Allow navigation if no learner ID set
    }

    if (_isChecking && !force) {
      return false; // Prevent multiple simultaneous checks
    }

    _isChecking = true;

    try {
      final pendingClasses = await PendingReviewService.getPendingReviews(
        _currentLearnerId!,
      );

      if (pendingClasses.isEmpty) {
        _isChecking = false;
        return true; // No pending reviews, allow navigation
      }

      // Show dialog for the oldest pending review
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => MandatoryReviewDialog(
            pendingClass: pendingClasses.first,
            learnerId: _currentLearnerId!,
            onReviewSubmitted: () {
              // After submitting, check if there are more pending reviews
              _isChecking = false;
              checkAndShowReviewDialog(context, force: true);
            },
          ),
        );
      }

      _isChecking = false;
      return false; // Block navigation until review is submitted
    } catch (e) {
      _isChecking = false;
      // On error, allow navigation to prevent blocking the app
      debugPrint('ReviewGuard error: $e');
      return true;
    }
  }

  /// Show all pending reviews in a list page
  static Future<void> showPendingReviewsPage(BuildContext context) async {
    if (_currentLearnerId == null) return;

    try {
      final pendingClasses = await PendingReviewService.getPendingReviews(
        _currentLearnerId!,
      );

      if (pendingClasses.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่มีคลาสที่ต้องรีวิว'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PendingReviewsListPage(
              pendingClasses: pendingClasses,
              learnerId: _currentLearnerId!,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get count of pending reviews (for badges)
  static Future<int> getPendingReviewCount() async {
    if (_currentLearnerId == null) return 0;

    try {
      final pendingClasses = await PendingReviewService.getPendingReviews(
        _currentLearnerId!,
      );
      return pendingClasses.length;
    } catch (_) {
      return 0;
    }
  }
}

/// Page to show list of all pending reviews
class PendingReviewsListPage extends StatefulWidget {
  final List<PendingReviewClass> pendingClasses;
  final int learnerId;

  const PendingReviewsListPage({
    super.key,
    required this.pendingClasses,
    required this.learnerId,
  });

  @override
  State<PendingReviewsListPage> createState() => _PendingReviewsListPageState();
}

class _PendingReviewsListPageState extends State<PendingReviewsListPage> {
  late List<PendingReviewClass> _pendingClasses;

  @override
  void initState() {
    super.initState();
    _pendingClasses = List.from(widget.pendingClasses);
  }

  void _showReviewDialog(PendingReviewClass pendingClass) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MandatoryReviewDialog(
        pendingClass: pendingClass,
        learnerId: widget.learnerId,
        onReviewSubmitted: () {
          setState(() {
            _pendingClasses.remove(pendingClass);
          });
          if (_pendingClasses.isEmpty) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('คลาสที่ต้องรีวิว'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _pendingClasses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ไม่มีคลาสที่ต้องรีวิวแล้ว',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ขอบคุณที่รีวิวทุกคลาส!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingClasses.length,
              itemBuilder: (context, index) {
                final pendingClass = _pendingClasses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _showReviewDialog(pendingClass),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Class banner or icon
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: pendingClass.bannerPictureUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          pendingClass.bannerPictureUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.school,
                                            size: 30,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.school,
                                        size: 30,
                                        color: Colors.grey[400],
                                      ),
                              ),
                              const SizedBox(width: 12),
                              // Class info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pendingClass.className,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(pendingClass.classFinish),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Arrow icon
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Review button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _showReviewDialog(pendingClass),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'รีวิวตอนนี้',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'เรียนจบวันนี้';
    } else if (difference.inDays == 1) {
      return 'เรียนจบเมื่อวาน';
    } else if (difference.inDays < 7) {
      return 'เรียนจบ ${difference.inDays} วันที่แล้ว';
    } else {
      return 'เรียนจบเมื่อ ${date.day}/${date.month}/${date.year}';
    }
  }
}
