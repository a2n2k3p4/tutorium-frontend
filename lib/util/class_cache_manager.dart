import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorium_frontend/service/classes.dart' as class_api;

class CachedClassData {
  final int id;
  final String className;
  final String classDescription;
  final String? bannerPictureUrl;
  final double rating;
  final int teacherId;
  final String? teacherName;
  final DateTime cachedAt;

  CachedClassData({
    required this.id,
    required this.className,
    required this.classDescription,
    this.bannerPictureUrl,
    required this.rating,
    required this.teacherId,
    this.teacherName,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'className': className,
    'classDescription': classDescription,
    'bannerPictureUrl': bannerPictureUrl,
    'rating': rating,
    'teacherId': teacherId,
    'teacherName': teacherName,
    'cachedAt': cachedAt.toIso8601String(),
  };

  factory CachedClassData.fromJson(Map<String, dynamic> json) {
    return CachedClassData(
      id: json['id'] as int,
      className: json['className'] as String,
      classDescription: json['classDescription'] as String,
      bannerPictureUrl: json['bannerPictureUrl'] as String?,
      rating: (json['rating'] as num).toDouble(),
      teacherId: json['teacherId'] as int,
      teacherName: json['teacherName'] as String?,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }

  factory CachedClassData.fromClassInfo(class_api.ClassInfo info) {
    return CachedClassData(
      id: info.id,
      className: info.className,
      classDescription: info.classDescription,
      bannerPictureUrl: info.bannerPictureUrl ?? info.bannerPicture,
      rating: info.rating,
      teacherId: info.teacherId,
      teacherName: info.teacherName,
    );
  }
}

class ClassCacheManager {
  static final ClassCacheManager _instance = ClassCacheManager._internal();
  factory ClassCacheManager() => _instance;
  ClassCacheManager._internal();

  static const String _cacheKeyPrefix = 'class_cache_';
  static const String _teacherClassesPrefix = 'teacher_classes_';
  static const Duration _cacheDuration = Duration(minutes: 5);

  // In-memory cache for faster access
  final Map<int, CachedClassData> _memoryCache = {};
  final Map<int, List<CachedClassData>> _teacherClassesCache = {};
  Timer? _backgroundRefreshTimer;

  void _log(String message) {
    debugPrint('🎓 [ClassCache] $message');
  }

  /// Initialize cache manager
  Future<void> initialize() async {
    _log('Initializing...');
    await _loadMemoryCache();
    _startBackgroundRefresh();
  }

  /// Load all cached classes into memory
  Future<void> _loadMemoryCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKeyPrefix));

      for (final key in keys) {
        final jsonStr = prefs.getString(key);
        if (jsonStr != null) {
          try {
            final data = CachedClassData.fromJson(json.decode(jsonStr));
            _memoryCache[data.id] = data;
          } catch (e) {
            _log('Failed to parse cached class from $key: $e');
          }
        }
      }
      _log('Loaded ${_memoryCache.length} classes into memory');
    } catch (e) {
      _log('Failed to load memory cache: $e');
    }
  }

  /// Get class by ID (from cache or fetch)
  Future<CachedClassData> getClass(
    int classId, {
    bool forceRefresh = false,
  }) async {
    // Check memory cache first
    if (!forceRefresh && _memoryCache.containsKey(classId)) {
      final cached = _memoryCache[classId]!;
      if (DateTime.now().difference(cached.cachedAt) < _cacheDuration) {
        _log('✅ Class $classId from memory cache');
        return cached;
      }
    }

    // Check persistent cache
    if (!forceRefresh) {
      final cached = await _getClassFromDisk(classId);
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) < _cacheDuration) {
        _memoryCache[classId] = cached;
        _log('✅ Class $classId from disk cache');
        return cached;
      }
    }

    // Fetch from API
    _log('🌐 Fetching class $classId from API');
    final info = await class_api.ClassInfo.fetchById(classId);

    // Try to get average rating in parallel
    double rating = info.rating;
    try {
      final avgRating = await class_api.ClassInfo.fetchAverageRating(classId);
      if (avgRating != null && avgRating > 0) {
        rating = avgRating;
      }
    } catch (e) {
      _log('Failed to fetch average rating for $classId: $e');
    }

    final cached = CachedClassData(
      id: info.id,
      className: info.className,
      classDescription: info.classDescription,
      bannerPictureUrl: info.bannerPictureUrl ?? info.bannerPicture,
      rating: rating,
      teacherId: info.teacherId,
      teacherName: info.teacherName,
    );

    await _saveClassToDisk(cached);
    _memoryCache[classId] = cached;

    return cached;
  }

  /// Get classes by teacher ID (with optimized fetching)
  Future<List<CachedClassData>> getClassesByTeacher(
    int teacherId, {
    String? teacherName,
    bool forceRefresh = false,
  }) async {
    List<CachedClassData>? previousCache;
    if (forceRefresh) {
      previousCache = _teacherClassesCache[teacherId];
      if (previousCache == null || previousCache.isEmpty) {
        previousCache = await _getTeacherClassesFromDisk(teacherId);
      }
    }

    // Check memory cache first
    if (!forceRefresh && _teacherClassesCache.containsKey(teacherId)) {
      final cached = _teacherClassesCache[teacherId]!;
      if (cached.isNotEmpty &&
          DateTime.now().difference(cached.first.cachedAt) < _cacheDuration) {
        _log(
          '✅ Teacher $teacherId classes from memory (${cached.length} items)',
        );
        return cached;
      }
    }

    // Check disk cache
    if (!forceRefresh) {
      final cached = await _getTeacherClassesFromDisk(teacherId);
      if (cached != null &&
          cached.isNotEmpty &&
          DateTime.now().difference(cached.first.cachedAt) < _cacheDuration) {
        _teacherClassesCache[teacherId] = cached;
        _log('✅ Teacher $teacherId classes from disk (${cached.length} items)');
        return cached;
      }
    }

    // Fetch from API with optimizations
    _log('🌐 Fetching teacher $teacherId classes from API');
    final classInfos = await class_api.ClassInfo.fetchByTeacher(
      teacherId,
      teacherName: teacherName,
    );

    _log('📊 API returned ${classInfos.length} classes');

    if (classInfos.isEmpty) {
      _log('⚠️ No classes found for teacher $teacherId');
      if (previousCache != null && previousCache.isNotEmpty) {
        _log(
          '♻️ Using cached data (${previousCache.length}) instead of empty API response for teacher $teacherId',
        );
        _teacherClassesCache[teacherId] = previousCache;
        return previousCache;
      }
      _teacherClassesCache[teacherId] = [];
      await _saveTeacherClassesToDisk(teacherId, []);
      return [];
    }

    // Convert to cached data directly (no extra API calls for fast loading)
    final classes = classInfos.map((info) {
      return CachedClassData(
        id: info.id,
        className: info.className,
        classDescription: info.classDescription.isEmpty
            ? 'No description'
            : info.classDescription,
        bannerPictureUrl: info.bannerPictureUrl ?? info.bannerPicture,
        rating: info.rating,
        teacherId: info.teacherId,
        teacherName: info.teacherName,
      );
    }).toList();

    // Save to cache
    await _saveTeacherClassesToDisk(teacherId, classes);
    _teacherClassesCache[teacherId] = classes;

    for (final cls in classes) {
      _memoryCache[cls.id] = cls;
    }

    _log('✅ Cached ${classes.length} classes for teacher $teacherId');
    return classes;
  }

  /// Background refresh for active data
  void _startBackgroundRefresh() {
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshActiveCache(),
    );
  }

  Future<void> _refreshActiveCache() async {
    _log('🔄 Background refresh started');

    // Refresh teacher classes that are in memory
    final teacherIds = _teacherClassesCache.keys.toList();
    for (final teacherId in teacherIds) {
      try {
        await getClassesByTeacher(teacherId, forceRefresh: true);
      } catch (e) {
        _log('Background refresh failed for teacher $teacherId: $e');
      }
    }
  }

  /// Save class to disk
  Future<void> _saveClassToDisk(CachedClassData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix${data.id}';
      await prefs.setString(key, json.encode(data.toJson()));
    } catch (e) {
      _log('Failed to save class ${data.id} to disk: $e');
    }
  }

  /// Get class from disk
  Future<CachedClassData?> _getClassFromDisk(int classId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix$classId';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        return CachedClassData.fromJson(json.decode(jsonStr));
      }
    } catch (e) {
      _log('Failed to get class $classId from disk: $e');
    }
    return null;
  }

  /// Save teacher classes to disk
  Future<void> _saveTeacherClassesToDisk(
    int teacherId,
    List<CachedClassData> classes,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_teacherClassesPrefix$teacherId';
      final jsonList = classes.map((c) => c.toJson()).toList();
      await prefs.setString(key, json.encode(jsonList));

      // Also save individual classes
      for (final cls in classes) {
        await _saveClassToDisk(cls);
      }
    } catch (e) {
      _log('Failed to save teacher $teacherId classes to disk: $e');
    }
  }

  /// Get teacher classes from disk
  Future<List<CachedClassData>?> _getTeacherClassesFromDisk(
    int teacherId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_teacherClassesPrefix$teacherId';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        final jsonList = json.decode(jsonStr) as List;
        return jsonList.map((j) => CachedClassData.fromJson(j)).toList();
      }
    } catch (e) {
      _log('Failed to get teacher $teacherId classes from disk: $e');
    }
    return null;
  }

  /// Refresh a single class entry without wiping the whole cache
  Future<void> refreshClass(int classId) async {
    try {
      _log('🔄 Refreshing class $classId');

      final info = await class_api.ClassInfo.fetchById(classId);

      double rating = info.rating;
      try {
        final avgRating = await class_api.ClassInfo.fetchAverageRating(classId);
        if (avgRating != null && avgRating > 0) {
          rating = avgRating;
        }
      } catch (e) {
        _log('Failed to refresh average rating for $classId: $e');
      }

      final refreshed = CachedClassData(
        id: info.id,
        className: info.className,
        classDescription: info.classDescription,
        bannerPictureUrl: info.bannerPictureUrl ?? info.bannerPicture,
        rating: rating,
        teacherId: info.teacherId,
        teacherName: info.teacherName,
      );

      // Update in-memory cache
      _memoryCache[classId] = refreshed;

      // Persist individual class cache
      await _saveClassToDisk(refreshed);

      final teacherId = refreshed.teacherId;

      // Update in-memory teacher list cache if available
      final teacherClasses = _teacherClassesCache[teacherId];
      if (teacherClasses != null) {
        final index = teacherClasses.indexWhere((cls) => cls.id == classId);
        if (index >= 0) {
          teacherClasses[index] = refreshed;
        } else {
          teacherClasses.add(refreshed);
        }
      }

      // Update persistent teacher list cache if present
      final diskClasses = await _getTeacherClassesFromDisk(teacherId);
      if (diskClasses != null && diskClasses.isNotEmpty) {
        final index = diskClasses.indexWhere((cls) => cls.id == classId);
        if (index >= 0) {
          diskClasses[index] = refreshed;
          await _saveTeacherClassesToDisk(teacherId, diskClasses);
        }
      }

      _log('✅ Class $classId refreshed in cache');
    } catch (e) {
      _log('Failed to refresh class $classId: $e');
      rethrow;
    }
  }

  /// Clear all cache
  Future<void> clearAll() async {
    _memoryCache.clear();
    _teacherClassesCache.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) =>
            k.startsWith(_cacheKeyPrefix) ||
            k.startsWith(_teacherClassesPrefix),
      );
      for (final key in keys) {
        await prefs.remove(key);
      }
      _log('🗑️ All cache cleared');
    } catch (e) {
      _log('Failed to clear cache: $e');
    }
  }

  /// Clear cache for specific teacher
  Future<void> clearTeacherCache(int teacherId) async {
    _teacherClassesCache.remove(teacherId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_teacherClassesPrefix$teacherId';
      await prefs.remove(key);
      _log('🗑️ Cache cleared for teacher $teacherId');
    } catch (e) {
      _log('Failed to clear teacher $teacherId cache: $e');
    }
  }

  /// Cleanup
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    _memoryCache.clear();
    _teacherClassesCache.clear();
  }
}
