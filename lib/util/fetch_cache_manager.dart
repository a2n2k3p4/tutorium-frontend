import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/util/cache_manager.dart';

/// FetchCacheManager - จัดการ cache พร้อม auto-refresh ทุก 2 วัน
/// รองรับการ fetch ข้อมูลจาก API พร้อมการ cache อัตโนมัติ
/// และการ refresh ข้อมูลเพื่อให้ข้อมูล fresh เสมอ
class FetchCacheManager<T> {
  final CacheManager<T> _cacheManager;
  final String _cacheKey;
  final Duration _refreshInterval;

  // Timer สำหรับ auto-refresh
  Timer? _refreshTimer;
  DateTime? _lastRefreshTime;
  bool _isRefreshing = false;

  FetchCacheManager({
    required String cacheKey,
    required CacheManager<T> cacheManager,
    Duration refreshInterval = const Duration(days: 2),
  }) : _cacheKey = cacheKey,
       _cacheManager = cacheManager,
       _refreshInterval = refreshInterval;

  /// ดึงข้อมูล พร้อม cache และ auto-refresh
  Future<T> fetch(
    Future<T> Function() fetcher, {
    bool forceRefresh = false,
  }) async {
    try {
      // ถ้า force refresh ให้ fetch เลยไม่ใช้ cache
      if (forceRefresh) {
        debugPrint('🔄 [FetchCache] Force refresh: $_cacheKey');
        final data = await fetcher();
        await _cacheManager.set(_cacheKey, data);
        _lastRefreshTime = DateTime.now();
        _isRefreshing = false;
        return data;
      }

      // ลองดึงจาก cache ก่อน
      final cachedData = await _cacheManager.get(_cacheKey);
      if (cachedData != null) {
        debugPrint('✅ [FetchCache] Using cached data: $_cacheKey');

        // ตรวจสอบว่าต้อง refresh หรือไม่ (แบบ background)
        _scheduleRefreshIfNeeded(fetcher);

        return cachedData;
      }

      // ถ้าไม่มี cache ให้ fetch เลย
      debugPrint('🔄 [FetchCache] No cache, fetching: $_cacheKey');
      final data = await fetcher();
      await _cacheManager.set(_cacheKey, data);
      _lastRefreshTime = DateTime.now();
      _isRefreshing = false;
      return data;
    } catch (e) {
      debugPrint('❌ [FetchCache] Error fetching $_cacheKey: $e');
      rethrow;
    }
  }

  /// ตรวจสอบว่าต้อง refresh หรือไม่ (background)
  void _scheduleRefreshIfNeeded(Future<T> Function() fetcher) {
    // ถ้ากำลังรีเฟรชอยู่แล้ว ห้ามรีเฟรชซ้ำ
    if (_isRefreshing) return;

    // ถ้ายังไม่มีการ refresh เลย ให้เริ่มนับเวลา
    if (_lastRefreshTime == null) {
      _startAutoRefresh(fetcher);
      return;
    }

    // ตรวจสอบว่าเกิน refresh interval หรือไม่
    final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
    if (timeSinceLastRefresh >= _refreshInterval) {
      _startAutoRefresh(fetcher);
    }
  }

  /// เริ่มต้น auto-refresh (background)
  void _startAutoRefresh(Future<T> Function() fetcher) {
    if (_isRefreshing) return;

    _isRefreshing = true;
    debugPrint('🔄 [FetchCache] Starting background refresh for $_cacheKey');

    // ทำการ refresh แบบ async (ไม่รอ)
    _performRefreshInBackground(fetcher);
  }

  /// ทำการ refresh แบบ background
  Future<void> _performRefreshInBackground(Future<T> Function() fetcher) async {
    try {
      final data = await fetcher();
      await _cacheManager.set(_cacheKey, data);
      _lastRefreshTime = DateTime.now();
      debugPrint('✅ [FetchCache] Background refresh completed: $_cacheKey');
    } catch (e) {
      debugPrint(
        '⚠️ [FetchCache] Background refresh failed for $_cacheKey: $e',
      );
    } finally {
      _isRefreshing = false;
    }
  }

  /// ดึงข้อมูลแบบ stream (realtime update)
  Stream<T> watchFetch(
    Future<T> Function() fetcher, {
    Duration pollInterval = const Duration(seconds: 30),
  }) async* {
    yield await fetch(fetcher);

    // Poll data ทุก ๆ pollInterval
    while (true) {
      await Future.delayed(pollInterval);
      try {
        yield await fetch(fetcher, forceRefresh: true);
      } catch (e) {
        debugPrint('⚠️ [FetchCache] Watch fetch error: $e');
      }
    }
  }

  /// ลบ cache
  Future<void> clear() async {
    await _cacheManager.remove(_cacheKey);
    _lastRefreshTime = null;
    _isRefreshing = false;
    _refreshTimer?.cancel();
    debugPrint('🗑️ [FetchCache] Cache cleared: $_cacheKey');
  }

  /// ยกเลิก auto-refresh timer
  void cancel() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isRefreshing = false;
    debugPrint('⏸️ [FetchCache] Auto-refresh cancelled: $_cacheKey');
  }

  /// ดู debug info
  Map<String, dynamic> getStatus() {
    return {
      'cache_key': _cacheKey,
      'is_refreshing': _isRefreshing,
      'last_refresh': _lastRefreshTime?.toIso8601String(),
      'refresh_interval_days': _refreshInterval.inDays,
    };
  }
}

/// Helper class สำหรับจัดการหลาย fetch caches พร้อมกัน
class FetchCachePool {
  static final FetchCachePool _instance = FetchCachePool._internal();

  factory FetchCachePool() => _instance;

  FetchCachePool._internal();

  final Map<String, FetchCacheManager> _managers = {};

  /// สร้าง หรือ ดึง FetchCacheManager สำหรับ key ที่กำหนด
  FetchCacheManager<T> getOrCreate<T>(
    String key,
    CacheManager<T> cacheManager, {
    Duration refreshInterval = const Duration(days: 2),
  }) {
    if (!_managers.containsKey(key)) {
      _managers[key] = FetchCacheManager<T>(
        cacheKey: key,
        cacheManager: cacheManager,
        refreshInterval: refreshInterval,
      );
    }
    return _managers[key] as FetchCacheManager<T>;
  }

  /// ลบ cache ทั้งหมด
  Future<void> clearAll() async {
    for (final manager in _managers.values) {
      manager.cancel();
    }
    debugPrint('🗑️ [FetchCachePool] All caches cleared');
  }

  /// ดู status ทั้งหมด
  List<Map<String, dynamic>> getAllStatus() {
    return _managers.values.map((m) => m.getStatus()).toList();
  }
}
