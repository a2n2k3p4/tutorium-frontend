import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/ClassSessions.dart'
    as class_session_api;
import 'package:tutorium_frontend/service/Classes.dart' as class_api;
import 'package:tutorium_frontend/service/Enrollments.dart' as enrollment_api;
import 'package:tutorium_frontend/service/Learners.dart' as learner_api;
import 'package:tutorium_frontend/service/Meetings.dart' as meeting_api;
import 'package:tutorium_frontend/service/Teachers.dart' as teacher_api;
import 'package:tutorium_frontend/service/Users.dart' as user_api;
import 'package:tutorium_frontend/util/cache_user.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

import '../learn/learn.dart';
import '../widgets/schedule_card_learner.dart';

class LearnerHomePage extends StatefulWidget {
  final VoidCallback onSwitch;

  const LearnerHomePage({super.key, required this.onSwitch});

  @override
  State<LearnerHomePage> createState() => _LearnerHomePageState();
}

class _LearnerHomePageState extends State<LearnerHomePage> {
  final List<_LearnerScheduleItem> _schedule = [];
  bool _isLoading = true;
  String? _errorMessage;

  void _log(String message) {
    debugPrint('📘 [LearnerHome] $message');
  }

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule({bool isRefresh = false}) async {
    _log('Loading schedule (refresh: $isRefresh)...');
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final learnerId = await _resolveLearnerId();
      if (learnerId == null) {
        _log('Failed to resolve learner ID.');
        throw Exception('ไม่พบข้อมูล Learner ของผู้ใช้คนนี้');
      }

      final token = await LocalStorage.getToken();
      _log('Resolved learnerId=$learnerId | token present=${token != null}.');

      final allEnrollments = await enrollment_api.Enrollment.fetchAll();
      _log('Fetched ${allEnrollments.length} enrollments from API.');

      final activeEnrollments = allEnrollments
          .where(
            (e) =>
                (e.enrollmentStatus.toLowerCase() == 'active') &&
                e.learnerId == learnerId,
          )
          .toList();
      _log('Active enrollments for learner: ${activeEnrollments.length}.');

      if (activeEnrollments.isEmpty) {
        if (mounted) {
          setState(() {
            _schedule.clear();
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }

      final sessionCountMap = <int, int>{};
      for (final enrollment in allEnrollments.where(
        (e) => e.enrollmentStatus.toLowerCase() == 'active',
      )) {
        sessionCountMap.update(
          enrollment.classSessionId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      _log('Computed learner counts for ${sessionCountMap.length} sessions.');

      final now = DateTime.now();
      final sessionCache = <int, class_session_api.ClassSession>{};
      final classCache = <int, class_api.ClassInfo>{};
      final teacherNameCache = <int, String>{};

      final List<_LearnerScheduleItem> items = [];

      for (final enrollment in activeEnrollments) {
        _log('Processing enrollment for session ${enrollment.classSessionId}');
        try {
          final session = await _fetchClassSession(
            enrollment.classSessionId,
            sessionCache,
          );

          final start = DateTime.parse(session.classStart).toLocal();
          final end = DateTime.parse(session.classFinish).toLocal();
          _log('Session ${session.id} runs $start -> $end');

          // Show all enrolled sessions (past, present, future)
          // This allows learners to see their enrollment history
          final hoursSinceEnd = now.difference(end).inHours;
          _log(
            'Session ${session.id} ended $hoursSinceEnd hours ago (showing anyway).',
          );

          final classInfo = await _fetchClassInfo(session.classId, classCache);
          final teacherName = await _resolveTeacherName(
            classInfo.teacherId,
            teacherNameCache,
          );

          String imagePath = classInfo.bannerPicture;
          if (imagePath.isEmpty) {
            imagePath = 'assets/images/guitar.jpg';
          }

          String meetingUrl = session.classUrl;
          if (meetingUrl.isEmpty) {
            final fetchedLink = await _fetchMeetingLink(session.id, token);
            meetingUrl = fetchedLink ?? '';
          }

          final enrolledLearner = sessionCountMap[session.id] ?? 1;

          items.add(
            _LearnerScheduleItem(
              classSessionId: session.id,
              className: classInfo.className.isNotEmpty
                  ? classInfo.className
                  : session.description,
              teacherName: teacherName,
              start: start,
              end: end,
              meetingUrl: meetingUrl,
              imagePath: imagePath,
              enrolledLearner: enrolledLearner,
            ),
          );
        } catch (e) {
          _log('Failed to process session ${enrollment.classSessionId}: $e');
        }
      }

      // Sort: upcoming first, then past (most recent first)
      items.sort((a, b) {
        final aNow = now.isBefore(a.end);
        final bNow = now.isBefore(b.end);
        if (aNow && !bNow) return -1; // a is upcoming, b is past
        if (!aNow && bNow) return 1; // a is past, b is upcoming
        // Both same category: sort by start time
        if (aNow) {
          return a.start.compareTo(b.start); // upcoming: earliest first
        } else {
          return b.start.compareTo(a.start); // past: most recent first
        }
      });
      _log('Prepared ${items.length} sessions (upcoming + past).');

      if (mounted) {
        setState(() {
          _schedule
            ..clear()
            ..addAll(items);
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      _log('Schedule load failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load schedule: $e';
        });
      }
    }
  }

  Future<int?> _resolveLearnerId() async {
    final cachedLearnerId = await LocalStorage.getLearnerId();
    if (cachedLearnerId != null) {
      _log('Found learner id in cache: $cachedLearnerId');
      return cachedLearnerId;
    }

    final userId = await LocalStorage.getUserId();
    if (userId == null) return null;

    try {
      final user = await UserCache().getUser(userId, forceRefresh: false);
      final learner = user.learner;
      if (learner != null) {
        _log('Resolved learner id from cache user object: ${learner.id}');
        await LocalStorage.saveLearnerId(learner.id);
        return learner.id;
      }
      final refreshed = await UserCache().refresh(userId);
      final refreshedLearner = refreshed.learner;
      if (refreshedLearner != null) {
        _log(
          'Resolved learner id after refreshing user: ${refreshedLearner.id}',
        );
        await LocalStorage.saveLearnerId(refreshedLearner.id);
        return refreshedLearner.id;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to resolve learner id: $e');
    }

    try {
      _log('Attempting to match learner via learners list for user $userId');
      final learners = await learner_api.Learner.fetchAll();
      final match = learners.where((l) => l.userId == userId).toList();
      if (match.isNotEmpty) {
        final learner = match.first;
        _log('Matched learner via learners list: ${learner.id}');
        await LocalStorage.saveLearnerId(learner.id);
        return learner.id;
      }
      _log('No learner entry matched for user $userId.');
    } catch (e) {
      _log('Failed to fetch learners list: $e');
    }
    return null;
  }

  Future<class_session_api.ClassSession> _fetchClassSession(
    int sessionId,
    Map<int, class_session_api.ClassSession> cache,
  ) async {
    if (cache.containsKey(sessionId)) {
      _log('Session $sessionId retrieved from cache.');
      return cache[sessionId]!;
    }
    _log('Fetching session $sessionId from API.');
    final session = await class_session_api.ClassSession.fetchById(sessionId);
    cache[sessionId] = session;
    return session;
  }

  Future<class_api.ClassInfo> _fetchClassInfo(
    int classId,
    Map<int, class_api.ClassInfo> cache,
  ) async {
    if (cache.containsKey(classId)) {
      _log('Class $classId retrieved from cache.');
      return cache[classId]!;
    }
    _log('Fetching class $classId from API.');
    final info = await class_api.ClassInfo.fetchById(classId);
    cache[classId] = info;
    return info;
  }

  Future<String> _resolveTeacherName(
    int teacherId,
    Map<int, String> cache,
  ) async {
    if (cache.containsKey(teacherId)) {
      return cache[teacherId]!;
    }

    if (teacherId == 0) {
      _log('Teacher ID missing for class; using fallback.');
      const fallback = 'Teacher';
      cache[teacherId] = fallback;
      return fallback;
    }

    try {
      final teacher = await teacher_api.Teacher.fetchById(teacherId);
      final teacherUser = await user_api.User.fetchById(teacher.userId);
      final name =
          '${teacherUser.firstName ?? ''} ${teacherUser.lastName ?? ''}'.trim();
      if (name.isNotEmpty) {
        cache[teacherId] = name;
        return name;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load teacher name: $e');
    }

    const fallback = 'Teacher';
    cache[teacherId] = fallback;
    return fallback;
  }

  Future<String?> _fetchMeetingLink(int sessionId, String? token) async {
    if (token == null || token.isEmpty) {
      _log('Skip meeting fetch for session $sessionId (no token).');
      return null;
    }

    try {
      final response = await meeting_api.MeetingService.fetchByClassSessionId(
        sessionId,
        token: token,
      );
      _log('Meeting raw response for session $sessionId: ${response.data}');
      String? link = response.link;
      if (link == null || link.isEmpty) {
        for (final entry in response.data.entries) {
          final value = entry.value;
          if (value is String && value.startsWith('http')) {
            link = value;
            break;
          }
        }
      }

      if (link != null && link.isNotEmpty) {
        _log('Meeting link for session $sessionId resolved: $link');
        return link;
      }

      _log('Meeting response for session $sessionId did not contain a URL.');
      return null;
    } catch (e) {
      _log('Meeting link fetch failed for session $sessionId: $e');
      return null;
    }
  }

  void _openClass(_LearnerScheduleItem item) {
    _log(
      'Opening class session ${item.classSessionId}. Meeting URL empty=${item.meetingUrl.isEmpty}.',
    );
    if (item.meetingUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยังไม่มีลิงก์เรียนสำหรับคลาสนี้ในตอนนี้'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearnPage(
          classSessionId: item.classSessionId,
          className: item.className,
          teacherName: item.teacherName,
          jitsiMeetingUrl: item.meetingUrl,
          isTeacher: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Learner Home",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 28.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _schedule.isEmpty
                        ? 'ไม่มีคลาสที่ลงทะเบียน'
                        : '${_schedule.length} คลาส',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14.0,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.school_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.change_circle,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: widget.onSwitch,
                      tooltip: 'Switch to Teacher Mode',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSchedule(isRefresh: true),
        color: Colors.amber,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            top: 24,
            left: 16,
            right: 16,
            bottom: 24,
          ),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber[100]!, Colors.amber[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Icon(Icons.history_edu, color: Colors.amber, size: 24),
                  SizedBox(width: 12),
                  Text(
                    "My Classes",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 22.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) ...[
              const SizedBox(height: 100),
              const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ] else if (_errorMessage != null) ...[
              _buildErrorSection(),
            ] else if (_schedule.isEmpty) ...[
              _buildEmptyState(),
            ] else ...[
              for (final item in _schedule) ...[
                GestureDetector(
                  onTap: () => _openClass(item),
                  child: ScheduleCardLearner(
                    className: item.className,
                    enrolledLearner: item.enrolledLearner,
                    teacherName: item.teacherName,
                    date: item.start,
                    startTime: TimeOfDay.fromDateTime(item.start),
                    endTime: TimeOfDay.fromDateTime(item.end),
                    imagePath: item.imagePath,
                    classSessionId: item.classSessionId,
                    classUrl: item.meetingUrl,
                    isTeacher: false,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _loadSchedule(),
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่อีกครั้ง'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy, size: 64, color: Colors.amber),
          ),
          const SizedBox(height: 20),
          const Text(
            'ยังไม่มีคลาสที่ลงทะเบียนไว้',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ลองค้นหาและลงทะเบียนคลาสที่คุณสนใจ',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LearnerScheduleItem {
  _LearnerScheduleItem({
    required this.classSessionId,
    required this.className,
    required this.teacherName,
    required this.start,
    required this.end,
    required this.meetingUrl,
    required this.imagePath,
    required this.enrolledLearner,
  });

  final int classSessionId;
  final String className;
  final String teacherName;
  final DateTime start;
  final DateTime end;
  final String meetingUrl;
  final String imagePath;
  final int enrolledLearner;
}
