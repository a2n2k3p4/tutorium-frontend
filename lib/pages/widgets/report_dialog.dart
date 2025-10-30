import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/reports.dart';

class ReportDialog extends StatefulWidget {
  final int classSessionId;
  final int reportUserId; // ผู้ที่ทำการรายงาน
  final int reportedUserId; // ผู้ที่ถูกรายงาน
  final String reportedUserName; // ชื่อผู้ที่ถูกรายงาน
  final VoidCallback? onReportSubmitted;

  const ReportDialog({
    super.key,
    required this.classSessionId,
    required this.reportUserId,
    required this.reportedUserId,
    required this.reportedUserName,
    this.onReportSubmitted,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<Map<String, String>> _reportReasons = [
    {'value': 'inappropriate_behavior', 'label': 'พฤติกรรมไม่เหมาะสม'},
    {'value': 'harassment', 'label': 'การล่วงละเมิด'},
    {'value': 'spam', 'label': 'สแปม'},
    {'value': 'teacher_absent', 'label': 'ครูไม่มาสอน'},
    {'value': 'poor_quality', 'label': 'คุณภาพการสอนไม่ดี'},
    {'value': 'other', 'label': 'อื่นๆ'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      setState(() {
        _errorMessage = 'กรุณาเลือกเหตุผลในการรายงาน';
      });
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'กรุณาระบุรายละเอียดการรายงาน';
      });
      return;
    }

    if (_descriptionController.text.trim().length < 10) {
      setState(() {
        _errorMessage = 'กรุณาระบุรายละเอียดอย่างน้อย 10 ตัวอักษร';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final report = Report(
        classSessionId: widget.classSessionId,
        reportDate: DateTime.now().toUtc(),
        reportDescription: _descriptionController.text.trim(),
        reportReason: _selectedReason!,
        reportStatus: 'pending',
        reportType: 'user_report',
        reportUserId: widget.reportUserId,
        reportedUserId: widget.reportedUserId,
      );

      await Report.create(report);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onReportSubmitted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งรายงานเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'รายงานผู้ใช้',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Text(
              'รายงาน: ${widget.reportedUserName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'ระบบจะตรวจสอบรายงานและดำเนินการตามความเหมาะสม',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Reason selection
            const Text(
              'เหตุผลในการรายงาน',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._reportReasons.map((reason) {
              final value = reason['value']!;
              final isSelected = _selectedReason == value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                title: Text(reason['label']!),
                onTap: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _selectedReason = value;
                          _errorMessage = null;
                        });
                      },
              );
            }),
            const SizedBox(height: 24),

            // Description
            const Text(
              'รายละเอียดเพิ่มเติม',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              enabled: !_isSubmitting,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'โปรดระบุรายละเอียดของปัญหา...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (_) {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Warning message
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'การรายงานเท็จอาจส่งผลต่อบัญชีของคุณ',
                      style: TextStyle(color: Colors.orange[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('ส่งรายงาน'),
        ),
      ],
    );
  }
}
