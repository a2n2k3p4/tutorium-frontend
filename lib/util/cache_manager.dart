import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Generic cache entry with expiration time
class CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;

  CacheEntry({required this.data, required this.cachedAt, required this.ttl});

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;

  Map<String, dynamic> toJson(dynamic Function(T) toJsonT) {
    return {
      'data': toJsonT(data),
      'cachedAt': cachedAt.toIso8601String(),
      'ttl': ttl.inSeconds,
    };
  }

  factory CacheEntry.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return CacheEntry<T>(
      data: fromJsonT(json['data']),
      cachedAt: DateTime.parse(json['cachedAt']),
      ttl: Duration(seconds: json['ttl']),
    );
  }
}

/// Generic cache manager with TTL support
class CacheManager<T> {
  final String _keyPrefix;
  final Duration _defaultTtl;
  final Map<String, CacheEntry<T>> _memoryCache = {};
  final dynamic Function(T) _toJson;
  final T Function(dynamic) _fromJson;

  CacheManager({
    required String keyPrefix,
    required Duration defaultTtl,
    required dynamic Function(T) toJson,
    required T Function(dynamic) fromJson,
  }) : _keyPrefix = keyPrefix,
       _defaultTtl = defaultTtl,
       _toJson = toJson,
       _fromJson = fromJson;

  /// Get from cache (memory first, then disk)
  Future<T?> get(String key, {bool memoryOnly = false}) async {
    final cacheKey = '$_keyPrefix:$key';

    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      final entry = _memoryCache[cacheKey]!;
      if (!entry.isExpired) {
        debugPrint('🟢 [Cache] Memory hit: $cacheKey');
        return entry.data;
      } else {
        debugPrint('🟡 [Cache] Memory expired: $cacheKey');
        _memoryCache.remove(cacheKey);
      }
    }

    if (memoryOnly) return null;

    // Check disk cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(cacheKey);
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr);
        final entry = CacheEntry<T>.fromJson(json, _fromJson);

        if (!entry.isExpired) {
          debugPrint('🟢 [Cache] Disk hit: $cacheKey');
          // Restore to memory
          _memoryCache[cacheKey] = entry;
          return entry.data;
        } else {
          debugPrint('🟡 [Cache] Disk expired: $cacheKey');
          await prefs.remove(cacheKey);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Cache] Disk read error for $cacheKey: $e');
    }

    debugPrint('🔴 [Cache] Miss: $cacheKey');
    return null;
  }

  /// Set cache (memory + disk)
  Future<void> set(String key, T data, {Duration? ttl}) async {
    final cacheKey = '$_keyPrefix:$key';
    final entry = CacheEntry<T>(
      data: data,
      cachedAt: DateTime.now(),
      ttl: ttl ?? _defaultTtl,
    );

    // Save to memory
    _memoryCache[cacheKey] = entry;

    // Save to disk
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(entry.toJson(_toJson));
      await prefs.setString(cacheKey, jsonStr);
      debugPrint('💾 [Cache] Saved: $cacheKey (TTL: ${entry.ttl.inSeconds}s)');
    } catch (e) {
      debugPrint('⚠️ [Cache] Disk write error for $cacheKey: $e');
    }
  }

  /// Remove from cache
  Future<void> remove(String key) async {
    final cacheKey = '$_keyPrefix:$key';
    _memoryCache.remove(cacheKey);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
      debugPrint('🗑️ [Cache] Removed: $cacheKey');
    } catch (e) {
      debugPrint('⚠️ [Cache] Remove error for $cacheKey: $e');
    }
  }

  /// Clear all cache for this prefix
  Future<void> clear() async {
    _memoryCache.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final keysToRemove = keys.where((k) => k.startsWith(_keyPrefix));
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      debugPrint('🗑️ [Cache] Cleared all: $_keyPrefix');
    } catch (e) {
      debugPrint('⚠️ [Cache] Clear error: $e');
    }
  }

  /// Get or fetch data with cache
  Future<T> getOrFetch(
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await get(key);
      if (cached != null) {
        return cached;
      }
    }

    debugPrint('🔄 [Cache] Fetching: $key');
    final data = await fetcher();
    await set(key, data, ttl: ttl);
    return data;
  }
}
