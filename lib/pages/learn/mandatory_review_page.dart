import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tutorium_frontend/service/reviews.dart' as reviews_service;
import 'package:tutorium_frontend/pages/widgets/report_dialog.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

class MandatoryReviewPage extends StatefulWidget {
  const MandatoryReviewPage({
    super.key,
    required this.classId,
    required this.className,
    required this.learnerId,
    this.classSessionId,
    this.teacherId,
    this.teacherName,
  });

  final int classId;
  final String className;
  final int learnerId;
  final int? classSessionId;
  final int? teacherId;
  final String? teacherName;

  @override
  State<MandatoryReviewPage> createState() => _MandatoryReviewPageState();
}

class _MandatoryReviewPageState extends State<MandatoryReviewPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  int? _selectedRating;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.indigo.shade50, Colors.blue.shade50],
              ),
            ),
            child: SafeArea(
              bottom: true,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                        bottom: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(theme),
                          const SizedBox(height: 24),
                          _buildClassCard(theme),
                          const SizedBox(height: 20),
                          _buildRatingSelector(theme),
                          const SizedBox(height: 20),
                          _buildCommentField(theme),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _buildErrorBanner(),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.classSessionId != null &&
                            widget.teacherId != null) ...[
                          _buildReportButton(theme),
                          const SizedBox(height: 12),
                        ],
                        _buildSubmitButton(theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รีวิวคลาสเพื่อปลดล็อก',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.blueGrey.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ให้คะแนนแบบ 0-5 ดาว และเขียนความคิดเห็นเพื่อช่วยให้ครูพัฒนาคลาสต่อไป',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.blueGrey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.indigo.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.class_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.className,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Class ID: ${widget.classId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blueGrey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ให้คะแนน (0-5 ดาว)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: List<Widget>.generate(6, (index) {
            final isSelected = _selectedRating == index;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    index == 0
                        ? Icons.remove_circle_outline
                        : Icons.star_rounded,
                    color: isSelected
                        ? Colors.white
                        : (index == 0
                              ? Colors.blueGrey.shade500
                              : Colors.amber.shade700),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text('$index'),
                ],
              ),
              showCheckmark: false,
              selected: isSelected,
              backgroundColor: Colors.white,
              selectedColor: Colors.blue.shade500,
              side: BorderSide(
                color: isSelected
                    ? Colors.blue.shade500
                    : Colors.blueGrey.shade100,
              ),
              onSelected: (value) {
                if (!value) return;
                setState(() {
                  _selectedRating = index;
                });
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCommentField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ความคิดเห็น (บังคับกรอก)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
            controller: _commentController,
            focusNode: _commentFocus,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText:
                  'บอกเราเกี่ยวกับประสบการณ์ของคุณในคลาสนี้... (อย่างน้อย 10 ตัวอักษร)',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.blueGrey.shade300,
              ),
              contentPadding: const EdgeInsets.all(20),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton(ThemeData theme) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _submitting ? null : _showReportDialog,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          foregroundColor: Colors.red.shade600,
          side: BorderSide(color: Colors.red.shade300, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.flag_outlined),
        label: const Text(
          'รายงานครู (ไม่บังคับ)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: _submitting ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 6,
        ),
        child: _submitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.send_rounded),
                  SizedBox(width: 12),
                  Text(
                    'ส่งรีวิวและดำเนินการต่อ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _errorMessage = null;
    });

    final rating = _selectedRating;
    if (rating == null) {
      setState(() {
        _errorMessage = 'กรุณาเลือกคะแนนก่อนส่ง';
      });
      return;
    }

    final comment = _commentController.text.trim();
    if (comment.length < 10) {
      setState(() {
        _errorMessage = 'กรุณาเขียนความคิดเห็นอย่างน้อย 10 ตัวอักษร';
      });
      _commentFocus.requestFocus();
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await reviews_service.Review.create(
        reviews_service.Review(
          classId: widget.classId,
          learnerId: widget.learnerId,
          rating: rating,
          comment: comment,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ขอบคุณสำหรับการรีวิว!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blue.shade600,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      String userFriendlyMessage;

      // Check if it's a duplicate review error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('duplicate') ||
          errorString.contains('unique') ||
          errorString.contains('constraint') ||
          (errorString.contains('500') &&
              (errorString.contains('key') ||
                  errorString.contains('violate')))) {
        userFriendlyMessage =
            '✅ คุณได้ส่งรีวิวสำหรับคลาสนี้ไปแล้ว!\nไม่สามารถส่งรีวิวซ้ำได้';

        // Show success dialog for duplicate case
        _showAlreadyReviewedDialog();
        return;
      } else if (errorString.contains('timeout') ||
          errorString.contains('408')) {
        userFriendlyMessage =
            'การเชื่อมต่อหมดเวลา กรุณาตรวจสอบอินเทอร์เน็ตและลองอีกครั้ง';
      } else if (errorString.contains('network') ||
          errorString.contains('503')) {
        userFriendlyMessage =
            'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาลองอีกครั้งภายหลัง';
      } else if (errorString.contains('400')) {
        userFriendlyMessage = 'ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบและลองอีกครั้ง';
      } else {
        userFriendlyMessage = 'ส่งรีวิวไม่สำเร็จ กรุณาลองอีกครั้ง';
      }

      setState(() {
        _errorMessage = userFriendlyMessage;
        _submitting = false;
      });
    }
  }

  void _showAlreadyReviewedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade600,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ส่งรีวิวแล้ว',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คุณได้ส่งรีวิวสำหรับคลาส "${widget.className}" ไปเรียบร้อยแล้ว',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'แต่ละคลาสสามารถรีวิวได้เพียงครั้งเดียวเท่านั้น',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Close review page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'เข้าใจแล้ว',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  Future<void> _showReportDialog() async {
    if (widget.classSessionId == null || widget.teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถรายงานได้ ข้อมูลไม่ครบถ้วน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userId = await LocalStorage.getUserId();
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลผู้ใช้'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        classSessionId: widget.classSessionId!,
        reportUserId: userId,
        reportedUserId: widget.teacherId!,
        reportedUserName: widget.teacherName ?? 'ครูผู้สอน',
      ),
    );
  }
}
