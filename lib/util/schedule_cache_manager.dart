import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/service/class_sessions.dart'
    as class_session_api;
import 'package:tutorium_frontend/service/classes.dart' as class_api;
import 'package:tutorium_frontend/service/teachers.dart' as teacher_api;
import 'package:tutorium_frontend/service/users.dart' as user_api;
import 'package:tutorium_frontend/util/cache_manager.dart';

/// Cached schedule item for learner
class CachedScheduleItem {
  final int classSessionId;
  final String className;
  final String teacherName;
  final DateTime start;
  final DateTime end;
  final String meetingUrl;
  final String imagePath;
  final int enrolledLearner;

  CachedScheduleItem({
    required this.classSessionId,
    required this.className,
    required this.teacherName,
    required this.start,
    required this.end,
    required this.meetingUrl,
    required this.imagePath,
    required this.enrolledLearner,
  });

  Map<String, dynamic> toJson() {
    return {
      'classSessionId': classSessionId,
      'className': className,
      'teacherName': teacherName,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'meetingUrl': meetingUrl,
      'imagePath': imagePath,
      'enrolledLearner': enrolledLearner,
    };
  }

  static CachedScheduleItem fromJson(Map<String, dynamic> json) {
    return CachedScheduleItem(
      classSessionId: json['classSessionId'],
      className: json['className'],
      teacherName: json['teacherName'],
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
      meetingUrl: json['meetingUrl'],
      imagePath: json['imagePath'],
      enrolledLearner: json['enrolledLearner'],
    );
  }
}

/// Schedule cache manager with background refresh
class ScheduleCacheManager {
  static final ScheduleCacheManager _instance =
      ScheduleCacheManager._internal();
  factory ScheduleCacheManager() => _instance;
  ScheduleCacheManager._internal();

  // Cache managers
  late final CacheManager<List<CachedScheduleItem>> _scheduleCache;
  late final CacheManager<class_session_api.ClassSession> _sessionCache;
  late final CacheManager<class_api.ClassInfo> _classCache;
  late final CacheManager<String> _teacherNameCache;

  // Background refresh
  Timer? _refreshTimer;
  bool _isInitialized = false;

  // Settings - Extended cache durations
  static const Duration _scheduleTtl = Duration(hours: 24);
  static const Duration _sessionTtl = Duration(days: 7);
  static const Duration _classTtl = Duration(days: 30);
  static const Duration _teacherNameTtl = Duration(days: 30);
  static const Duration _refreshInterval = Duration(minutes: 5);

  void initialize() {
    if (_isInitialized) return;

    _scheduleCache = CacheManager<List<CachedScheduleItem>>(
      keyPrefix: 'schedule',
      defaultTtl: _scheduleTtl,
      toJson: (items) => items.map((e) => e.toJson()).toList(),
      fromJson: (json) =>
          (json as List).map((e) => CachedScheduleItem.fromJson(e)).toList(),
    );

    _sessionCache = CacheManager<class_session_api.ClassSession>(
      keyPrefix: 'session',
      defaultTtl: _sessionTtl,
      toJson: (session) => {
        'id': session.id,
        'classId': session.classId,
        'classStart': session.classStart,
        'classFinish': session.classFinish,
        'enrollmentDeadline': session.enrollmentDeadline,
        'classStatus': session.classStatus,
        'description': session.description,
        'learnerLimit': session.learnerLimit,
        'price': session.price,
        'classUrl': session.classUrl,
      },
      fromJson: (json) => class_session_api.ClassSession(
        id: json['id'],
        createdAt: '',
        updatedAt: '',
        classId: json['classId'],
        description: json['description'],
        price: json['price'].toDouble(),
        learnerLimit: json['learnerLimit'],
        enrollmentDeadline: json['enrollmentDeadline'],
        classStart: json['classStart'],
        classFinish: json['classFinish'],
        classStatus: json['classStatus'],
        classUrl: json['classUrl'] ?? '',
      ),
    );

    _classCache = CacheManager<class_api.ClassInfo>(
      keyPrefix: 'class',
      defaultTtl: _classTtl,
      toJson: (cls) => {
        'id': cls.id,
        'className': cls.className,
        'classDescription': cls.classDescription,
        'bannerPicture': cls.bannerPicture,
        'bannerPictureUrl': cls.bannerPictureUrl,
        'teacherId': cls.teacherId,
        'teacherName': cls.teacherName,
        'rating': cls.rating,
        'enrolledLearners': cls.enrolledLearners,
        'categories': cls.categories,
      },
      fromJson: (json) => class_api.ClassInfo(
        id: json['id'] ?? 0,
        className: json['className'] ?? '',
        classDescription: json['classDescription'] ?? '',
        bannerPicture: json['bannerPicture'] as String?,
        bannerPictureUrl: json['bannerPictureUrl'] as String?,
        teacherId: json['teacherId'] ?? 0,
        teacherName: json['teacherName'] as String?,
        rating: (json['rating'] ?? 0.0).toDouble(),
        enrolledLearners: json['enrolledLearners'] is num
            ? (json['enrolledLearners'] as num).toInt()
            : int.tryParse('${json['enrolledLearners']}'),
        categories:
            (json['categories'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      ),
    );

    _teacherNameCache = CacheManager<String>(
      keyPrefix: 'teacher_name',
      defaultTtl: _teacherNameTtl,
      toJson: (name) => name,
      fromJson: (json) => json.toString(),
    );

    _isInitialized = true;
    debugPrint('✅ [ScheduleCache] Initialized');
  }

  /// Start background refresh
  void startBackgroundRefresh(
    Future<List<CachedScheduleItem>> Function() fetcher,
    void Function(List<CachedScheduleItem>) onUpdate,
  ) {
    stopBackgroundRefresh();

    _refreshTimer = Timer.periodic(_refreshInterval, (timer) async {
      try {
        debugPrint('🔄 [ScheduleCache] Background refresh started');
        final items = await fetcher();
        await _scheduleCache.set('learner_schedule', items);
        onUpdate(items);
        debugPrint('✅ [ScheduleCache] Background refresh completed');
      } catch (e) {
        debugPrint('⚠️ [ScheduleCache] Background refresh failed: $e');
      }
    });

    debugPrint('✅ [ScheduleCache] Started background refresh (30s interval)');
  }

  /// Stop background refresh
  void stopBackgroundRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    debugPrint('🛑 [ScheduleCache] Stopped background refresh');
  }

  /// Get cached schedule
  Future<List<CachedScheduleItem>?> getSchedule(int learnerId) async {
    return await _scheduleCache.get('learner_schedule');
  }

  /// Save schedule to cache
  Future<void> saveSchedule(
    int learnerId,
    List<CachedScheduleItem> items,
  ) async {
    await _scheduleCache.set('learner_schedule', items);
  }

  /// Get cached class session
  Future<class_session_api.ClassSession?> getSession(int sessionId) async {
    return await _sessionCache.get(sessionId.toString());
  }

  /// Save class session to cache
  Future<void> saveSession(class_session_api.ClassSession session) async {
    await _sessionCache.set(session.id.toString(), session);
  }

  /// Get or fetch class session
  Future<class_session_api.ClassSession> getOrFetchSession(
    int sessionId,
  ) async {
    return await _sessionCache.getOrFetch(sessionId.toString(), () async {
      debugPrint('🔄 [ScheduleCache] Fetching session $sessionId from API');
      return await class_session_api.ClassSession.fetchById(sessionId);
    });
  }

  /// Get cached class info
  Future<class_api.ClassInfo?> getClassInfo(int classId) async {
    return await _classCache.get(classId.toString());
  }

  /// Save class info to cache
  Future<void> saveClassInfo(class_api.ClassInfo classInfo) async {
    await _classCache.set(classInfo.id.toString(), classInfo);
  }

  /// Get or fetch class info
  Future<class_api.ClassInfo> getOrFetchClassInfo(int classId) async {
    return await _classCache.getOrFetch(classId.toString(), () async {
      debugPrint('🔄 [ScheduleCache] Fetching class $classId from API');
      return await class_api.ClassInfo.fetchById(classId);
    });
  }

  /// Get cached teacher name
  Future<String?> getTeacherName(int teacherId) async {
    return await _teacherNameCache.get(teacherId.toString());
  }

  /// Save teacher name to cache
  Future<void> saveTeacherName(int teacherId, String name) async {
    await _teacherNameCache.set(teacherId.toString(), name);
  }

  /// Get or fetch teacher name
  Future<String> getOrFetchTeacherName(int teacherId) async {
    if (teacherId == 0) {
      return 'Teacher';
    }

    return await _teacherNameCache.getOrFetch(teacherId.toString(), () async {
      debugPrint(
        '🔄 [ScheduleCache] Fetching teacher $teacherId name from API',
      );
      try {
        final teacher = await teacher_api.Teacher.fetchById(teacherId);
        final teacherUser = await user_api.User.fetchById(teacher.userId);
        final name =
            '${teacherUser.firstName ?? ''} ${teacherUser.lastName ?? ''}'
                .trim();
        return name.isNotEmpty ? name : 'Teacher';
      } catch (e) {
        debugPrint('⚠️ [ScheduleCache] Failed to fetch teacher name: $e');
        return 'Teacher';
      }
    });
  }

  /// Clear all schedule cache
  Future<void> clearAll() async {
    await _scheduleCache.clear();
    await _sessionCache.clear();
    await _classCache.clear();
    await _teacherNameCache.clear();
    debugPrint('🗑️ [ScheduleCache] Cleared all cache');
  }

  /// Dispose resources
  void dispose() {
    stopBackgroundRefresh();
    debugPrint('🛑 [ScheduleCache] Disposed');
  }
}
