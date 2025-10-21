import 'package:flutter/material.dart';
import 'package:tutorium_frontend/service/enrollments.dart' as enrollment_api;
import 'package:tutorium_frontend/service/learners.dart' as learner_api;
import 'package:tutorium_frontend/pages/home/teacher/register/teacher_register.dart';
import 'package:tutorium_frontend/service/teacher_registration_service.dart';
import 'package:tutorium_frontend/util/cache_user.dart';
import 'package:tutorium_frontend/util/local_storage.dart';
import 'package:tutorium_frontend/util/schedule_cache_manager.dart';
import 'package:tutorium_frontend/util/image_cache_manager.dart';
import 'package:tutorium_frontend/services/notification_scheduler_service.dart';

import '../learn/learn.dart';
import '../learn/class_detail_page.dart';
import '../widgets/schedule_card_learner.dart';
import '../widgets/skeleton_loading.dart';

class LearnerHomePage extends StatefulWidget {
  final VoidCallback onSwitch;

  const LearnerHomePage({super.key, required this.onSwitch});

  @override
  LearnerHomePageState createState() => LearnerHomePageState();
}

class LearnerHomePageState extends State<LearnerHomePage> {
  final List<_LearnerScheduleItem> _schedule = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCheckingTeacherStatus = false;

  // Cache managers
  final _scheduleCache = ScheduleCacheManager();
  final _imageCache = ImageCacheManager();

  void _log(String message) {
    debugPrint('📘 [LearnerHome] $message');
  }

  @override
  void initState() {
    super.initState();
    _scheduleCache.initialize();
    _loadSchedule();
    _startBackgroundRefresh();
  }

  @override
  void dispose() {
    _scheduleCache.stopBackgroundRefresh();
    super.dispose();
  }

  void _startBackgroundRefresh() {
    _scheduleCache.startBackgroundRefresh(() => _fetchScheduleData(), (items) {
      if (mounted) {
        setState(() {
          _schedule
            ..clear()
            ..addAll(items.map(_toScheduleItem));
        });
        _log('🔄 Background refresh updated ${items.length} items');
      }
    });
  }

  /// Public method to refresh data when network reconnects
  void refreshData() {
    _log('🔄 Refreshing data due to network reconnection');
    _loadSchedule(isRefresh: true);
  }

  Future<void> _handleSwitchToTeacher() async {
    if (_isCheckingTeacherStatus) return;

    setState(() {
      _isCheckingTeacherStatus = true;
    });

    try {
      final userId = await LocalStorage.getUserId();
      if (userId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ในระบบ');
      }

      final eligibility =
          await TeacherRegistrationService.checkTeacherEligibility(userId);

      if (!mounted) return;

      if (eligibility.isAlreadyTeacher) {
        widget.onSwitch();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สลับไปโหมดครูแล้ว พร้อมสร้างคลาสได้ทันที'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final message = eligibility.hasEnoughBalance
          ? 'คุณยังไม่ได้สมัครเป็นครู ต้องชำระค่าลงทะเบียน 200 บาทก่อนเริ่มสอน'
          : 'ยอดเงินปัจจุบัน ${eligibility.currentBalance.toStringAsFixed(2)} บาท ไม่เพียงพอสำหรับค่าลงทะเบียนครู 200 บาท';

      final shouldRegister = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('สมัครเป็นครู'),
          content: Text('$message\n\nต้องการดำเนินการต่อหรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('สมัครเป็นครู'),
            ),
          ],
        ),
      );

      if (shouldRegister == true && mounted) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => const TeacherRegisterPage()),
        );

        if (!mounted) return;

        if (result == true) {
          widget.onSwitch();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('สมัครสำเร็จ! สลับไปโหมดครูให้แล้ว'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ยังไม่ได้สมัครเป็นครู โปรดลองอีกครั้งเมื่อพร้อม'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingTeacherStatus = false;
        });
      } else {
        _isCheckingTeacherStatus = false;
      }
    }
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

      // Try to load from cache first
      if (!isRefresh) {
        final cachedItems = await _scheduleCache.getSchedule(learnerId);
        if (cachedItems != null && cachedItems.isNotEmpty) {
          _log('🟢 Loaded ${cachedItems.length} items from cache');
          final scheduleItems = cachedItems.map(_toScheduleItem).toList();

          // Prefetch images in background
          final imageUrls = cachedItems
              .map((e) => e.imagePath)
              .where((url) => url.isNotEmpty && url.startsWith('http'))
              .toList();
          _imageCache.prefetchImages(imageUrls);

          if (mounted) {
            setState(() {
              _schedule
                ..clear()
                ..addAll(scheduleItems);
              _isLoading = false;
              _errorMessage = null;
            });
          }

          // Fetch fresh data in background
          _fetchScheduleData()
              .then((freshItems) async {
                await _scheduleCache.saveSchedule(learnerId, freshItems);
                if (mounted) {
                  setState(() {
                    _schedule
                      ..clear()
                      ..addAll(freshItems.map(_toScheduleItem));
                  });
                  _log(
                    '🔄 Updated with fresh data (${freshItems.length} items)',
                  );
                }
              })
              .catchError((e) {
                _log('⚠️ Background fetch failed: $e');
              });

          return;
        }
      }

      // Fetch fresh data
      final items = await _fetchScheduleData();
      await _scheduleCache.saveSchedule(learnerId, items);

      if (mounted) {
        setState(() {
          _schedule
            ..clear()
            ..addAll(items.map(_toScheduleItem));
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

  Future<List<CachedScheduleItem>> _fetchScheduleData() async {
    final learnerId = await _resolveLearnerId();
    if (learnerId == null) {
      throw Exception('ไม่พบข้อมูล Learner ของผู้ใช้คนนี้');
    }

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
      return [];
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
    final List<CachedScheduleItem> items = [];

    for (final enrollment in activeEnrollments) {
      _log('Processing enrollment for session ${enrollment.classSessionId}');
      try {
        // Use cache manager for session
        final session = await _scheduleCache.getOrFetchSession(
          enrollment.classSessionId,
        );

        final start = DateTime.parse(session.classStart).toLocal();
        final end = DateTime.parse(session.classFinish).toLocal();

        // Use cache manager for class info
        final classInfo = await _scheduleCache.getOrFetchClassInfo(
          session.classId,
        );

        // Use cache manager for teacher name
        final teacherName = await _scheduleCache.getOrFetchTeacherName(
          classInfo.teacherId,
        );

        String imagePath =
            classInfo.bannerPictureUrl ?? classInfo.bannerPicture ?? '';
        if (imagePath.isEmpty) {
          imagePath = 'assets/images/guitar.jpg';
        }

        // Use class_url from session directly (auto-generated by backend)
        String meetingUrl = session.classUrl;

        final enrolledLearner = sessionCountMap[session.id] ?? 1;

        items.add(
          CachedScheduleItem(
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

    return items;
  }

  _LearnerScheduleItem _toScheduleItem(CachedScheduleItem cached) {
    return _LearnerScheduleItem(
      classSessionId: cached.classSessionId,
      className: cached.className,
      teacherName: cached.teacherName,
      start: cached.start,
      end: cached.end,
      meetingUrl: cached.meetingUrl,
      imagePath: cached.imagePath,
      enrolledLearner: cached.enrolledLearner,
    );
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
        final learnerId = learner.id;
        if (learnerId != null) {
          _log('Matched learner via learners list: $learnerId');
          await LocalStorage.saveLearnerId(learnerId);
          return learnerId;
        }
        _log('Learner match missing id for user $userId');
      }
      _log('No learner entry matched for user $userId.');
    } catch (e) {
      _log('Failed to fetch learners list: $e');
    }
    return null;
  }

  bool _canCancelClass(_LearnerScheduleItem item) {
    final now = DateTime.now();
    final hoursUntilClass = item.start.difference(now).inHours;
    return hoursUntilClass >= 2;
  }

  Future<void> _cancelClass(_LearnerScheduleItem item) async {
    if (!_canCancelClass(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถยกเลิกคลาสได้ (ต้องยกเลิกก่อน 2 ชั่วโมง)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: Text('คุณต้องการยกเลิกคลาส "${item.className}" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ไม่ใช่'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยันการยกเลิก'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final learnerId = await _resolveLearnerId();
      if (learnerId == null) {
        throw Exception('ไม่พบข้อมูล Learner');
      }

      // หา enrollment id
      final allEnrollments = await enrollment_api.Enrollment.fetchAll();
      final enrollment = allEnrollments.firstWhere(
        (e) =>
            e.learnerId == learnerId &&
            e.classSessionId == item.classSessionId &&
            e.enrollmentStatus.toLowerCase() == 'active',
      );

      // ตรวจสอบว่า enrollment มี id หรือไม่
      if (enrollment.id == null) {
        throw Exception('Enrollment ID not found');
      }

      // ลบ enrollment
      await enrollment_api.Enrollment.delete(enrollment.id!);

      // Cancel scheduled notifications for this class
      await NotificationSchedulerService().cancelForSession(
        item.classSessionId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ยกเลิกคลาสสำเร็จ และยกเลิกการแจ้งเตือนแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload schedule
        await _loadSchedule(isRefresh: true);
      }
    } catch (e) {
      _log('Failed to cancel class: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openClass(_LearnerScheduleItem item) async {
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

    // Check if user has viewed class details before
    final hasViewed = await ClassDetailPage.hasViewed(item.classSessionId);

    if (!mounted) return;

    if (hasViewed) {
      // Go directly to LearnPage if already viewed
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
    } else {
      // Show ClassDetailPage first
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClassDetailPage(
            classSessionId: item.classSessionId,
            className: item.className,
            teacherName: item.teacherName,
            jitsiMeetingUrl: item.meetingUrl,
            isTeacher: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: isMediumScreen ? 70 : 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Learner Home",
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: isSmallScreen
                            ? 20.0
                            : isMediumScreen
                            ? 24.0
                            : 28.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _schedule.isEmpty
                          ? 'ไม่มีคลาสที่ลงทะเบียน'
                          : '${_schedule.length} คลาส',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isSmallScreen ? 12.0 : 14.0,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 8,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                      child: Icon(
                        Icons.school_rounded,
                        color: Colors.amber,
                        size: isSmallScreen ? 24 : 32,
                      ),
                    ),
                    IconButton(
                      icon: _isCheckingTeacherStatus
                          ? SizedBox(
                              width: isSmallScreen ? 20 : 24,
                              height: isSmallScreen ? 20 : 24,
                              child: const CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.amber,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.change_circle,
                              color: Colors.amber,
                              size: isSmallScreen ? 24 : 32,
                            ),
                      onPressed: _isCheckingTeacherStatus
                          ? null
                          : _handleSwitchToTeacher,
                      tooltip: 'Switch to Teacher Mode',
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                      constraints: const BoxConstraints(),
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
        strokeWidth: 3,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const LoadingListSkeleton(itemCount: 3);
    } else if (_errorMessage != null) {
      return _buildErrorSection();
    } else if (_schedule.isEmpty) {
      return _buildEmptyState();
    } else {
      return Column(
        key: const ValueKey('schedule_list'),
        children: [
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
                onCancel: () => _cancelClass(item),
                canCancel: _canCancelClass(item),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    }
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
            color: Colors.grey.withValues(alpha: 0.1),
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
            color: Colors.grey.withValues(alpha: 0.1),
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
