import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorium_frontend/models/models.dart';
import 'package:tutorium_frontend/pages/home/teacher/create_session_page.dart';
import 'package:tutorium_frontend/pages/learn/learn.dart';
import 'package:tutorium_frontend/pages/widgets/class_session_service.dart';
import 'package:tutorium_frontend/service/classes.dart' as class_api;
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
  final Set<int> _uploadingBannerClassIds = <int>{};
  final ImagePicker _imagePicker = ImagePicker();

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

  // ---------- Helper functions for deduping and filtering enrollments ----------

  /// Dedupe enrollments by student_id or user.id to prevent duplicates
  List<Map<String, dynamic>> _dedupeEnrollments(
    List<Map<String, dynamic>> raw,
  ) {
    final seen = <dynamic>{};
    final out = <Map<String, dynamic>>[];

    for (final e in raw) {
      final user = e['user'] as Map<String, dynamic>?;
      // Use student_id if available, fallback to user id or enrollment id
      final key = user != null ? (user['student_id'] ?? user['id']) : e['id'];
      if (key == null) continue; // Skip if no key found
      if (seen.add(key)) {
        out.add(e);
      } else {
        // Duplicate found - log if needed
        debugPrint('⚠️ Duplicate enrollment for key: $key');
      }
    }

    return out;
  }

  /// Filter enrollments to only pending statuses
  List<Map<String, dynamic>> _filterPending(List<Map<String, dynamic>> list) {
    final pendingStatuses = {'pending', 'waiting'};
    return list.where((e) {
      final status = (e['enrollment_status'] ?? '').toString().toLowerCase();
      return pendingStatuses.contains(status);
    }).toList();
  }

  /// Check if user is a student (not teacher or other roles)
  bool _isStudentUser(Map<String, dynamic>? user) {
    if (user == null) return false;
    final role = (user['role'] ?? '').toString().toLowerCase();
    final isStudentFlag = user['is_student'] == true;
    // Accept if role is 'student' or 'learner', or is_student flag is true
    return role == 'student' || role == 'learner' || isStudentFlag;
  }

  /// Filter to only confirmed student enrollments (exclude teachers/non-students)
  List<Map<String, dynamic>> _confirmedStudentEnrollments(
    List<Map<String, dynamic>> raw,
  ) {
    final goodStatuses = {'enrolled', 'confirmed', 'active'};
    return raw.where((e) {
      final user = e['user'] as Map<String, dynamic>?;
      final status = (e['enrollment_status'] ?? '').toString().toLowerCase();
      return goodStatuses.contains(status) && _isStudentUser(user);
    }).toList();
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
        forceRefresh: !isBackgroundRefresh,
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

      // 2. ดึง Sessions ทั้งหมดในครั้งเดียว (BATCH)
      final classIds = classes.map((c) => c.id).toList();
      final sessions = await ClassSessionService.getSessionsByClasses(classIds);

      // 3. ดึง Enrollments ทั้งหมดในครั้งเดียว (BATCH)
      final allSessionIds = sessions.values
          .expand((s) => s)
          .map((s) => s.id)
          .toList();

      final enrollments = await ClassSessionService.getEnrollmentsBySessions(
        allSessionIds,
      );

      // Dedupe enrollments by student_id or user.id
      final dedupedEnrollments = <int, List<Map<String, dynamic>>>{};
      enrollments.forEach((sessionId, rawList) {
        final unique = _dedupeEnrollments(rawList);
        dedupedEnrollments[sessionId] = unique;
      });

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
          _sessionEnrollments = dedupedEnrollments; // Use deduped data
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
            ..._buildSessionsList(classItem, displaySessions),
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
    final borderRadius = BorderRadius.circular(12);
    final imageUrl = classItem.bannerPicture;
    final isUploading = _isClassBannerUploading(classItem.id);

    Widget buildPlaceholder() {
      return Container(
        color: Colors.blue[50],
        alignment: Alignment.center,
        child: Icon(
          Icons.class_outlined,
          color: Colors.blue[600],
          size: size * 0.45,
        ),
      );
    }

    Widget buildImage() {
      if (imageUrl == null || imageUrl.isEmpty) {
        return buildPlaceholder();
      }

      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => buildPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Stack(
            children: [
              buildPlaceholder(),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        },
      );
    }

    final overlayGradient = Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.08),
              Colors.black.withValues(alpha: 0.45),
            ],
          ),
        ),
      ),
    );

    final cameraBadge = Positioned(
      bottom: 6,
      right: 6,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.black.withValues(alpha: 0.55),
        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
      ),
    );

    final changeLabel = Positioned(
      bottom: 6,
      left: 6,
      child: AnimatedOpacity(
        opacity: isUploading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Change',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );

    final centerCamera = Align(
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: isUploading ? 0.75 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.28),
            boxShadow: [
              if (!isUploading)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
            ],
          ),
          child: const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );

    final uploadingShield = isUploading
        ? Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: borderRadius,
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    final content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(borderRadius: borderRadius, child: buildImage()),
          ),
          overlayGradient,
          centerCamera,
          cameraBadge,
          changeLabel,
          uploadingShield,
        ],
      ),
    );

    final tooltipMessage = isUploading
        ? 'Updating banner...'
        : 'Tap to change banner image';

    return Tooltip(
      message: tooltipMessage,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: isUploading ? null : () => _handleChangeBanner(classItem),
          child: content,
        ),
      ),
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

  List<Widget> _buildSessionsList(
    ClassModel classItem,
    List<ClassSession> sessions,
  ) {
    return sessions.map((session) {
      final rawEnrollments = _sessionEnrollments[session.id] ?? [];

      // Filter only confirmed STUDENT enrollments (exclude teachers/non-students)
      final confirmed = _confirmedStudentEnrollments(rawEnrollments);
      final enrolledCount = confirmed.length;

      // Get pending enrollments separately
      final pending = _filterPending(rawEnrollments);

      // Prevent division by zero and clamp progress to 0.0-1.0
      final learnerLimit = session.learnerLimit <= 0 ? 1 : session.learnerLimit;
      var progressPercent = enrolledCount / learnerLimit;
      progressPercent = progressPercent.clamp(0.0, 1.0);

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
            const SizedBox(height: 12),

            // Join Classroom Button (no time check)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.video_call, size: 20),
                label: const Text('เข้าห้องเรียนทันที'),
                onPressed: () => _joinNow(classItem, session),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // Enrolled Students (Confirmed)
            if (confirmed.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Enrolled Students (${confirmed.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ..._buildEnrolledStudents(confirmed),
            ],

            // Pending Students (if any)
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Pending Registrations (${pending.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 8),
              ..._buildPendingStudents(pending),
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
      final user = enrollment['user'] as Map<String, dynamic>?;

      // Handle null or missing user data safely
      final firstName = (user?['first_name'] ?? 'Unknown').toString();
      final lastName = (user?['last_name'] ?? '').toString();
      final studentId = (user?['student_id'] ?? '—').toString();
      final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
      final status = enrollment['enrollment_status']?.toString() ?? 'unknown';

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
                initial,
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
                    '$firstName $lastName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Student ID: $studentId',
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
                status,
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

  List<Widget> _buildPendingStudents(List<Map<String, dynamic>> enrollments) {
    return enrollments.map((enrollment) {
      final user = enrollment['user'] as Map<String, dynamic>?;

      // Handle null or missing user data safely
      final firstName = (user?['first_name'] ?? 'Unknown').toString();
      final lastName = (user?['last_name'] ?? '').toString();
      final studentId = (user?['student_id'] ?? '—').toString();
      final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
      final status = enrollment['enrollment_status']?.toString() ?? 'pending';

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.orange[100],
              child: Text(
                initial,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$firstName $lastName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Student ID: $studentId',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  bool _isClassBannerUploading(int classId) =>
      _uploadingBannerClassIds.contains(classId);

  Future<String?> _pickBannerBase64() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        return null;
      }

      final extension = pickedFile.name.split('.').last.toLowerCase();
      const allowedExtensions = {'jpg', 'jpeg', 'png', 'heic', 'heif'};
      if (!allowedExtensions.contains(extension)) {
        _showSnack(
          'รองรับเฉพาะไฟล์ .jpg, .jpeg, .png, .heic และ .heif เท่านั้น',
          backgroundColor: Colors.red.shade600,
        );
        return null;
      }

      final fileBytes = await pickedFile.readAsBytes();
      return base64Encode(fileBytes);
    } on PlatformException catch (e) {
      debugPrint('Image picker error: $e');
      _showSnack(
        'ไม่สามารถเปิดคลังรูปภาพได้',
        backgroundColor: Colors.red.shade600,
      );
    } catch (e) {
      debugPrint('Unexpected image picker error: $e');
      _showSnack(
        'เกิดข้อผิดพลาดในการเลือกรูป',
        backgroundColor: Colors.red.shade600,
      );
    }
    return null;
  }

  Future<void> _handleChangeBanner(ClassModel classItem) async {
    final base64Image = await _pickBannerBase64();
    if (base64Image == null) return;

    final added = _uploadingBannerClassIds.add(classItem.id);
    if (added && mounted) {
      setState(() {});
    }

    try {
      final currentInfo = await class_api.ClassInfo.fetchById(classItem.id);
      final payload = currentInfo.copyWith(bannerPicture: base64Image);

      await class_api.ClassInfo.update(classItem.id, payload);

      // Refresh cache for this class so UI picks up the new banner quickly
      await _classCache.refreshClass(classItem.id);
      await _loadData(isBackgroundRefresh: false);

      _showSnack(
        'อัปเดตรูปหน้าปกคลาสเรียบร้อยแล้ว',
        backgroundColor: Colors.green.shade600,
      );
    } catch (e) {
      debugPrint('Failed to update banner for class ${classItem.id}: $e');
      _showSnack(
        'ไม่สามารถอัปเดตรูปคลาสได้ กรุณาลองใหม่อีกครั้ง',
        backgroundColor: Colors.red.shade600,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingBannerClassIds.remove(classItem.id);
        });
      } else {
        _uploadingBannerClassIds.remove(classItem.id);
      }
    }
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
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

  /// Join classroom immediately (no time check)
  Future<void> _joinNow(ClassModel classItem, ClassSession session) async {
    try {
      // Get Jitsi URL from session (already created by backend)
      final jitsiUrl = session.classUrl;

      if (jitsiUrl == null || jitsiUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ยังไม่พบลิงก์ห้องเรียน (Jitsi URL)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get teacher name (simple approach - can be improved)
      String teacherName = 'Teacher';
      try {
        // Fetch from cache or use default
        final classInfo = await ClassSessionService().fetchClassInfo(
          classItem.id,
        );
        teacherName = classInfo.teacherName;
      } catch (e) {
        debugPrint('⚠️ Could not fetch teacher name: $e');
      }

      // Set role: teacher or not
      final isTeacher = widget.teacherId == classItem.teacherId;

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LearnPage(
            classSessionId: session.id,
            className: classItem.className,
            teacherName: teacherName,
            jitsiMeetingUrl: jitsiUrl,
            isTeacher: isTeacher,
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Join classroom failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เข้าเรียนไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
