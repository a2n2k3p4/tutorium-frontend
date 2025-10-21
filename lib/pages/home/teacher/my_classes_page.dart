import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tutorium_frontend/models/models.dart';
import 'package:tutorium_frontend/pages/home/teacher/create_session_page.dart';
import 'package:tutorium_frontend/pages/widgets/class_session_service.dart';
import 'package:tutorium_frontend/util/class_cache_manager.dart';

class MyClassesPage extends StatefulWidget {
  final int teacherId;

  const MyClassesPage({super.key, required this.teacherId});

  @override
  State<MyClassesPage> createState() => _MyClassesPageState();
}

class _MyClassesPageState extends State<MyClassesPage> {
  List<ClassModel> _classes = [];
  Map<int, List<ClassSession>> _classSessions = {};
  Map<int, List<Map<String, dynamic>>> _sessionEnrollments = {};
  final Map<int, int?> _selectedSessionByClass = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  final _classCache = ClassCacheManager();

  @override
  void initState() {
    super.initState();
    _classCache.initialize();
    _loadData();
    // Auto-refresh ทุก 2 นาที (เพิ่มจาก 1 นาที เพื่อลด load)
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _loadData(isBackgroundRefresh: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool isBackgroundRefresh = false}) async {
    if (!isBackgroundRefresh && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // 1. ดึงรายการ Classes ของ Teacher จาก cache
      final cachedClasses = await _classCache.getClassesByTeacher(
        widget.teacherId,
        forceRefresh: isBackgroundRefresh,
      );

      final classes = cachedClasses
          .map(
            (cached) => ClassModel(
              id: cached.id,
              className: cached.className,
              classDescription: cached.classDescription,
              bannerPicture: cached.bannerPictureUrl,
              rating: cached.rating,
              teacherId: cached.teacherId,
            ),
          )
          .toList();

      // 2. ดึง Sessions และ Enrollments แบบ parallel
      final sessionsFutures = classes.map((classItem) async {
        final sessions = await ClassSessionService.getSessionsByClass(
          classItem.id,
        );
        return MapEntry(classItem.id, sessions);
      });

      final sessionsResults = await Future.wait(sessionsFutures);
      final sessions = Map.fromEntries(sessionsResults);

      // 3. ดึง Enrollments ของทุก Session แบบ parallel
      final allSessionIds = sessions.values
          .expand((s) => s)
          .map((s) => s.id)
          .toList();

      final enrollmentsFutures = allSessionIds.map((sessionId) async {
        final enrollments = await ClassSessionService.getEnrollmentsBySession(
          sessionId,
        );
        return MapEntry(sessionId, enrollments);
      });

      final enrollmentsResults = await Future.wait(enrollmentsFutures);
      final enrollments = Map.fromEntries(enrollmentsResults);

      final updatedSelection = <int, int?>{};
      for (final classItem in classes) {
        final sessionList = sessions[classItem.id] ?? [];
        final currentSelection = _selectedSessionByClass[classItem.id];
        if (currentSelection != null &&
            sessionList.any((session) => session.id == currentSelection)) {
          updatedSelection[classItem.id] = currentSelection;
        } else {
          updatedSelection[classItem.id] = null;
        }
      }

      if (mounted) {
        setState(() {
          _classes = classes;
          _classSessions = sessions;
          _sessionEnrollments = enrollments;
          _selectedSessionByClass
            ..clear()
            ..addAll(updatedSelection);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading my classes data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (!isBackgroundRefresh) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'My Classes & Sessions',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
          ? _buildEmptyState()
          : _buildClassesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Classes Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first class to get started!',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _classes.length,
        itemBuilder: (context, index) {
          final classItem = _classes[index];
          final sessions = _classSessions[classItem.id] ?? [];

          return _buildClassCard(classItem, sessions);
        },
      ),
    );
  }

  Widget _buildClassCard(ClassModel classItem, List<ClassSession> sessions) {
    final selectedSessionId = _selectedSessionByClass[classItem.id];
    final filteredSessions = selectedSessionId == null
        ? sessions
        : sessions
              .where((session) => session.id == selectedSessionId)
              .toList(growable: false);
    final List<ClassSession> displaySessions =
        (selectedSessionId != null && filteredSessions.isEmpty)
        ? sessions
        : filteredSessions;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: _buildClassThumbnail(classItem),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                classItem.className,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.green[700]),
              tooltip: 'Add Session',
              onPressed: () => _handleCreateSession(classItem),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              classItem.classDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber[700]),
                const SizedBox(width: 4),
                Text(
                  classItem.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.event, size: 16, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  '${sessions.length} sessions',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            _buildNoSessions(classItem)
          else ...[
            _buildSessionSelector(classItem, sessions, selectedSessionId),
            const SizedBox(height: 12),
            ..._buildSessionsList(displaySessions),
          ],
        ],
      ),
    );
  }

  Future<void> _handleCreateSession(ClassModel classItem) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSessionPage(classModel: classItem),
      ),
    );

    if (created == true) {
      await _loadData();
    }
  }

  Widget _buildClassThumbnail(ClassModel classItem) {
    const double size = 60;
    final imageUrl = classItem.bannerPicture;

    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildClassThumbnailPlaceholder(size: size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _buildClassThumbnailPlaceholder(size: size),
      ),
    );
  }

  Widget _buildClassThumbnailPlaceholder({double size = 60}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.class_, color: Colors.blue[700], size: size * 0.55),
    );
  }

  Widget _buildSessionSelector(
    ClassModel classItem,
    List<ClassSession> sessions,
    int? selectedSessionId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.event_note, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: selectedSessionId,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                onChanged: (value) {
                  setState(() {
                    _selectedSessionByClass[classItem.id] = value;
                  });
                },
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All sessions'),
                  ),
                  ...sessions.map(
                    (session) => DropdownMenuItem<int?>(
                      value: session.id,
                      child: Text(
                        _sessionOptionLabel(session),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sessionOptionLabel(ClassSession session) {
    final dateLabel = _formatDateTime(session.classStart);
    final description = session.description.trim();
    final baseLabel = description.isEmpty
        ? 'Session ${session.id}'
        : description;
    final shortened = baseLabel.length > 36
        ? '${baseLabel.substring(0, 33)}...'
        : baseLabel;
    return '$dateLabel - $shortened';
  }

  Widget _buildNoSessions(ClassModel classItem) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No sessions created yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first session for this class',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Session'),
            onPressed: () => _handleCreateSession(classItem),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSessionsList(List<ClassSession> sessions) {
    return sessions.map((session) {
      final enrollments = _sessionEnrollments[session.id] ?? [];
      final enrolledCount = enrollments.length;
      final progressPercent = enrolledCount / session.learnerLimit;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.description,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(session.classStart),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(session.classStatus),
              ],
            ),
            const SizedBox(height: 12),

            // Enrollment Progress
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enrolled',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '$enrolledCount / ${session.learnerLimit}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getProgressColor(progressPercent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            _getProgressColor(progressPercent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Session Info
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  Icons.attach_money,
                  '฿${session.price.toStringAsFixed(0)}',
                  Colors.green,
                ),
                _buildInfoChip(
                  Icons.schedule,
                  _formatDuration(session.classStart, session.classFinish),
                  Colors.blue,
                ),
                _buildInfoChip(
                  Icons.event_available,
                  'Deadline: ${_formatDate(session.enrollmentDeadline)}',
                  Colors.orange,
                ),
              ],
            ),

            // Enrolled Students
            if (enrollments.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Enrolled Students',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ..._buildEnrolledStudents(enrollments),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'scheduled':
        color = Colors.blue;
        icon = Icons.schedule;
        break;
      case 'ongoing':
        color = Colors.green;
        icon = Icons.play_circle;
        break;
      case 'completed':
        color = Colors.grey;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEnrolledStudents(List<Map<String, dynamic>> enrollments) {
    return enrollments.map((enrollment) {
      final user = enrollment['user'];

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue[100],
              child: Text(
                user['first_name'][0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user['first_name']} ${user['last_name']}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Student ID: ${user['student_id']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                enrollment['enrollment_status'],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getProgressColor(double progress) {
    if (progress >= 1.0) return Colors.red;
    if (progress >= 0.75) return Colors.orange;
    if (progress >= 0.5) return Colors.blue;
    return Colors.green;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDuration(DateTime start, DateTime finish) {
    final duration = finish.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}
