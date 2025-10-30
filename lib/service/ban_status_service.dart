import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/service/api_client.dart';
import 'package:tutorium_frontend/service/ban_learners.dart';
import 'package:tutorium_frontend/service/ban_teachers.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

/// Service for checking and managing ban status
class BanStatusService {
  static final BanStatusService _instance = BanStatusService._internal();
  factory BanStatusService() => _instance;
  BanStatusService._internal();

  static final ApiClient _client = ApiClient();

  // Cache for ban status (5 minutes TTL)
  final _cache = <int, _BanCacheEntry>{};
  final _cacheDuration = const Duration(minutes: 5);

  // Stream controller for ban status changes
  final _banStatusController = StreamController<BanStatusInfo>.broadcast();
  Stream<BanStatusInfo> get banStatusStream => _banStatusController.stream;

  void _log(String message) {
    debugPrint('🚫 [BanStatus] $message');
  }

  /// Check if current user is banned
  Future<BanStatusInfo> checkCurrentUserBanStatus() async {
    final userId = await LocalStorage.getUserId();
    if (userId == null) {
      return BanStatusInfo.notBanned();
    }

    return checkUserBanStatus(userId);
  }

  /// Check ban status for specific user with caching
  Future<BanStatusInfo> checkUserBanStatus(int userId) async {
    // Check cache first
    final cached = _cache[userId];
    if (cached != null && !cached.isExpired) {
      _log('Using cached ban status for user $userId');
      return cached.info;
    }

    try {
      _log('Fetching ban status for user $userId');

      // Check both learner and teacher bans in parallel
      final results = await Future.wait([
        _checkLearnerBan(userId),
        _checkTeacherBan(userId),
      ]);

      final learnerInfo = results[0];
      final teacherInfo = results[1];

      // Return the most restrictive ban (earliest ban end if both banned)
      BanStatusInfo info;
      if (learnerInfo.isBanned && teacherInfo.isBanned) {
        final earlierBan = learnerInfo.banEnd!.isBefore(teacherInfo.banEnd!)
            ? learnerInfo
            : teacherInfo;
        info = earlierBan;
      } else if (learnerInfo.isBanned) {
        info = learnerInfo;
      } else if (teacherInfo.isBanned) {
        info = teacherInfo;
      } else {
        info = BanStatusInfo.notBanned();
      }

      // Cache the result
      _cache[userId] = _BanCacheEntry(
        info: info,
        expiresAt: DateTime.now().add(_cacheDuration),
      );

      // Emit to stream
      _banStatusController.add(info);

      return info;
    } catch (e) {
      _log('Error checking ban status: $e');
      // Return not banned on error to avoid blocking user
      return BanStatusInfo.notBanned();
    }
  }

  Future<BanStatusInfo> _checkLearnerBan(int userId) async {
    try {
      // Get learner bans filtered by user (backend should support this)
      final bans = await BanLearner.fetchAll(
        query: {'user_id': userId.toString()},
      );

      if (bans.isEmpty) return BanStatusInfo.notBanned();

      // Find active ban (ban_end > now)
      final now = DateTime.now();
      for (final ban in bans) {
        final banEnd = DateTime.parse(ban.banEnd);
        if (banEnd.isAfter(now)) {
          return BanStatusInfo(
            isBanned: true,
            banEnd: banEnd,
            banStart: DateTime.parse(ban.banStart),
            reason: ban.banDescription,
            roleType: 'learner',
          );
        }
      }

      return BanStatusInfo.notBanned();
    } catch (e) {
      _log('Error checking learner ban: $e');
      return BanStatusInfo.notBanned();
    }
  }

  Future<BanStatusInfo> _checkTeacherBan(int userId) async {
    try {
      final bans = await BanTeacher.fetchAll(
        query: {'user_id': userId.toString()},
      );

      if (bans.isEmpty) return BanStatusInfo.notBanned();

      final now = DateTime.now();
      for (final ban in bans) {
        final banEnd = DateTime.parse(ban.banEnd);
        if (banEnd.isAfter(now)) {
          return BanStatusInfo(
            isBanned: true,
            banEnd: banEnd,
            banStart: DateTime.parse(ban.banStart),
            reason: ban.banDescription,
            roleType: 'teacher',
          );
        }
      }

      return BanStatusInfo.notBanned();
    } catch (e) {
      _log('Error checking teacher ban: $e');
      return BanStatusInfo.notBanned();
    }
  }

  /// Get flag count for learner
  Future<int> getLearnerFlagCount() async {
    try {
      final learnerId = await LocalStorage.getLearnerId();
      if (learnerId == null) return 0;

      final response = await _client.getJsonMap('/learners/$learnerId');
      return response['flag_count'] ?? 0;
    } catch (e) {
      _log('Error getting learner flag count: $e');
      return 0;
    }
  }

  /// Get flag count for teacher
  Future<int> getTeacherFlagCount(int teacherId) async {
    try {
      final response = await _client.getJsonMap('/teachers/$teacherId');
      return response['flag_count'] ?? 0;
    } catch (e) {
      _log('Error getting teacher flag count: $e');
      return 0;
    }
  }

  /// Invalidate cache for user (call this after ban status changes)
  void invalidateCache(int userId) {
    _cache.remove(userId);
    _log('Cache invalidated for user $userId');
  }

  /// Clear all cache
  void clearCache() {
    _cache.clear();
    _log('All cache cleared');
  }

  void dispose() {
    _banStatusController.close();
  }
}

/// Ban status information
class BanStatusInfo {
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @visibleForTesting
  static void resetClock() {
    clock = DateTime.now;
  }

  final bool isBanned;
  final DateTime? banEnd;
  final DateTime? banStart;
  final String? reason;
  final String? roleType; // 'learner' or 'teacher'

  BanStatusInfo({
    required this.isBanned,
    this.banEnd,
    this.banStart,
    this.reason,
    this.roleType,
  });

  factory BanStatusInfo.notBanned() {
    return BanStatusInfo(isBanned: false);
  }

  Duration? get remainingDuration {
    if (!isBanned || banEnd == null) return null;
    final remaining = banEnd!.difference(clock());
    return remaining.isNegative ? null : remaining;
  }

  String get formattedRemainingTime {
    final duration = remainingDuration;
    if (duration == null) return '';

    if (duration.inDays > 0) {
      return '${duration.inDays} วัน ${duration.inHours % 24} ชั่วโมง';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ชั่วโมง ${duration.inMinutes % 60} นาที';
    } else {
      return '${duration.inMinutes} นาที';
    }
  }
}

/// Cache entry for ban status
class _BanCacheEntry {
  final BanStatusInfo info;
  final DateTime expiresAt;

  _BanCacheEntry({required this.info, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
