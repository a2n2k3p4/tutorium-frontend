import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/util/cache_user.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

/// AutoRefreshManager - จัดการการ refresh ข้อมูลอัตโนมัติทุก 5 นาที
/// ทำงานเบื้องหลังแบบ smooth ไม่แสดง loading indicator
/// ป้องกันปัญหาข้อมูลชนกันเมื่อมีหลายคนใช้งาน
class AutoRefreshManager {
  // Singleton instance
  static final AutoRefreshManager _instance = AutoRefreshManager._internal();

  factory AutoRefreshManager() => _instance;

  AutoRefreshManager._internal();

  // Configuration
  static const Duration refreshInterval = Duration(minutes: 5);
  static const Duration retryInterval = Duration(seconds: 30);

  // State
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _isEnabled = false;
  int? _currentUserId;
  DateTime? _lastRefreshTime;
  int _refreshCount = 0;
  int _errorCount = 0;

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isRefreshing => _isRefreshing;
  DateTime? get lastRefreshTime => _lastRefreshTime;
  int get refreshCount => _refreshCount;
  int get errorCount => _errorCount;

  /// เริ่มต้นระบบ auto-refresh
  /// เรียกใช้หลัง login สำเร็จ
  void start(int userId) {
    debugPrint("DEBUG AutoRefresh: Starting auto-refresh for user $userId");

    _currentUserId = userId;
    _isEnabled = true;
    _refreshCount = 0;
    _errorCount = 0;

    // Cancel timer เดิม (ถ้ามี)
    stop();

    // เริ่ม timer ใหม่
    _scheduleNextRefresh(refreshInterval);

    debugPrint(
      "DEBUG AutoRefresh: Auto-refresh started, will refresh every ${refreshInterval.inMinutes} minutes",
    );
  }

  /// หยุดระบบ auto-refresh
  /// เรียกใช้เมื่อ logout หรือ dispose app
  void stop() {
    debugPrint("DEBUG AutoRefresh: Stopping auto-refresh");

    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isEnabled = false;
    _currentUserId = null;

    debugPrint("DEBUG AutoRefresh: Auto-refresh stopped");
  }

  /// Pause auto-refresh ชั่วคราว
  void pause() {
    if (!_isEnabled) return;

    debugPrint("DEBUG AutoRefresh: Pausing auto-refresh");
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Resume auto-refresh
  void resume() {
    if (!_isEnabled || _currentUserId == null) return;

    debugPrint("DEBUG AutoRefresh: Resuming auto-refresh");
    _scheduleNextRefresh(refreshInterval);
  }

  /// Force refresh ทันที (แต่ยังคง smooth)
  Future<bool> refreshNow() async {
    if (_currentUserId == null) {
      debugPrint("DEBUG AutoRefresh: Cannot refresh - no user logged in");
      return false;
    }

    return await _performRefresh();
  }

  /// กำหนดเวลา refresh ครั้งถัดไป
  void _scheduleNextRefresh(Duration delay) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(delay, _performRefresh);

    debugPrint(
      "DEBUG AutoRefresh: Next refresh scheduled in ${delay.inMinutes} minutes",
    );
  }

  /// ทำการ refresh จริง (background, smooth, no loading)
  Future<bool> _performRefresh() async {
    if (_isRefreshing || _currentUserId == null) {
      debugPrint(
        "DEBUG AutoRefresh: Skipping refresh - already refreshing or no user",
      );
      return false;
    }

    _isRefreshing = true;

    try {
      debugPrint(
        "DEBUG AutoRefresh: Starting background refresh for user $_currentUserId (attempt ${_refreshCount + 1})",
      );

      final startTime = DateTime.now();

      // 1. Fetch ข้อมูลใหม่จาก API (background)
      final updatedUser = await UserCache().refresh(_currentUserId!);

      final duration = DateTime.now().difference(startTime);

      // 2. อัพเดท local storage (smooth, no UI blocking)
      await LocalStorage.saveUserProfile(_userToCacheJson(updatedUser));

      // 3. อัพเดท timestamp
      _lastRefreshTime = DateTime.now();
      _refreshCount++;
      _errorCount = 0; // Reset error count on success

      debugPrint(
        "DEBUG AutoRefresh: Refresh completed successfully in ${duration.inMilliseconds}ms",
      );
      debugPrint(
        "DEBUG AutoRefresh: Updated data - balance=${updatedUser.balance}, teacher=${updatedUser.teacher != null}",
      );

      // Schedule ครั้งถัดไป
      if (_isEnabled) {
        _scheduleNextRefresh(refreshInterval);
      }

      _isRefreshing = false;
      return true;
    } catch (e) {
      _errorCount++;

      debugPrint(
        "ERROR AutoRefresh: Failed to refresh (error #$_errorCount): $e",
      );

      // Retry strategy: ถ้า error ให้ retry เร็วขึ้น
      if (_isEnabled) {
        final retryDelay = _errorCount < 3 ? retryInterval : refreshInterval;

        debugPrint(
          "DEBUG AutoRefresh: Will retry in ${retryDelay.inSeconds} seconds",
        );

        _scheduleNextRefresh(retryDelay);
      }

      _isRefreshing = false;
      return false;
    }
  }

  /// รีเซ็ตสถิติ
  void resetStats() {
    _refreshCount = 0;
    _errorCount = 0;
    _lastRefreshTime = null;

    debugPrint("DEBUG AutoRefresh: Statistics reset");
  }

  /// ดูสถานะปัจจุบัน
  Map<String, dynamic> getStatus() {
    return {
      'enabled': _isEnabled,
      'refreshing': _isRefreshing,
      'user_id': _currentUserId,
      'last_refresh': _lastRefreshTime?.toIso8601String(),
      'refresh_count': _refreshCount,
      'error_count': _errorCount,
      'next_refresh_in_seconds': _refreshTimer != null
          ? 'scheduled'
          : 'not scheduled',
    };
  }

  /// ดู debug info
  void printStatus() {
    debugPrint("=== AutoRefresh Status ===");
    debugPrint("Enabled: $_isEnabled");
    debugPrint("Refreshing: $_isRefreshing");
    debugPrint("User ID: $_currentUserId");
    debugPrint("Last Refresh: ${_lastRefreshTime?.toString() ?? 'Never'}");
    debugPrint("Refresh Count: $_refreshCount");
    debugPrint("Error Count: $_errorCount");
    debugPrint("========================");
  }
}

/// Helper function สำหรับ convert user เป็น JSON
Map<String, dynamic> _userToCacheJson(dynamic user) {
  return {
    'ID': user.id,
    'student_id': user.studentId,
    'first_name': user.firstName,
    'last_name': user.lastName,
    'gender': user.gender,
    'phone_number': user.phoneNumber,
    'balance': user.balance,
    'ban_count': user.banCount,
    'profile_picture': user.profilePicture,
    'Teacher': user.teacher == null
        ? null
        : {
            'ID': user.teacher!.id,
            'user_id': user.teacher!.userId,
            'description': user.teacher!.description,
            'flag_count': user.teacher!.flagCount,
            'email': user.teacher!.email,
          },
    'Learner': user.learner == null
        ? null
        : {
            'ID': user.learner!.id,
            'user_id': user.learner!.userId,
            'flag_count': user.learner!.flagCount,
          },
  }..removeWhere((key, value) => value == null);
}
