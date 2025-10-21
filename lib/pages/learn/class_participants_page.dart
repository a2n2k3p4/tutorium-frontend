import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/enrollments.dart';
import 'package:tutorium_frontend/pages/widgets/report_dialog.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

class ClassParticipantsPage extends StatefulWidget {
  final int classSessionId;
  final String className;

  const ClassParticipantsPage({
    super.key,
    required this.classSessionId,
    required this.className,
  });

  @override
  State<ClassParticipantsPage> createState() => _ClassParticipantsPageState();
}

class _ClassParticipantsPageState extends State<ClassParticipantsPage> {
  List<Enrollment> _enrollments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final enrollments = await Enrollment.fetchAll(
        query: {'class_session_id': widget.classSessionId.toString()},
      );

      if (mounted) {
        setState(() {
          _enrollments = enrollments
              .where((e) => e.enrollmentStatus == 'active')
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showReportDialog(int learnerId, String learnerName) async {
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
        classSessionId: widget.classSessionId,
        reportUserId: userId,
        reportedUserId: learnerId,
        reportedUserName: learnerName,
        onReportSubmitted: () {
          _loadParticipants();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้เรียนในคลาส'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'เกิดข้อผิดพลาด',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadParticipants,
                      child: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            )
          : _enrollments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีผู้เรียนในคลาสนี้',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.purple.shade50,
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.purple.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'คุณสามารถรายงานผู้เรียนที่มีพฤติกรรมไม่เหมาะสมได้',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _enrollments.length,
                    itemBuilder: (context, index) {
                      final enrollment = _enrollments[index];
                      return _buildParticipantCard(enrollment);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildParticipantCard(Enrollment enrollment) {
    final learnerName = 'ผู้เรียน #${enrollment.learnerId}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.person,
                color: Colors.purple.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    learnerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Learner ID: ${enrollment.learnerId}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _showReportDialog(enrollment.learnerId, learnerName),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade300),
              ),
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('รายงาน'),
            ),
          ],
        ),
      ),
    );
  }
}
