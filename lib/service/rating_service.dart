import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/service/api_client.dart' show ApiException;
import 'package:tutorium_frontend/service/classes.dart' as class_api;
import 'package:tutorium_frontend/service/teachers.dart' as teacher_api;

/// RatingService - จัดการ average rating ของ classes
/// - Fetch rating จาก API
/// - Cache result
/// - Debug logging ครบครัน
/// - Error handling
class RatingService {
  static final RatingService _instance = RatingService._internal();

  factory RatingService() => _instance;

  RatingService._internal();

  // Cache: classId -> rating
  final Map<int, RatingCacheEntry> _ratingCache = {};
  final Map<int, RatingCacheEntry> _teacherRatingCache = {};

  // Configuration
  static const Duration cacheTtl = Duration(hours: 1);
  static const String debugTag = '🌟 [RatingService]';
  static const String teacherDebugTag = '🌟 [TeacherRatingService]';

  /// ===== STEP 1: Fetch Rating with Caching =====
  /// Input: classId
  /// Process: Check cache -> Fetch API -> Cache result
  /// Output: rating (double)
  Future<double> getRating(int classId) async {
    debugPrint('$debugTag STEP 1 START: getRating(classId=$classId)');

    // STEP 1.1: Check cache
    final cached = _getRatingFromCache(classId);
    if (cached != null) {
      debugPrint(
        '$debugTag ✅ STEP 1.1 CACHE HIT: classId=$classId, rating=$cached',
      );
      return cached;
    }

    debugPrint(
      '$debugTag ⏭️  STEP 1.1 CACHE MISS: classId=$classId, fetching from API...',
    );

    // STEP 1.2: Fetch from API
    final rating = await _fetchRatingFromAPI(classId);

    // STEP 1.3: Cache result
    _cacheRating(classId, rating);
    debugPrint('$debugTag ✅ STEP 1.3 CACHED: classId=$classId, rating=$rating');

    debugPrint('$debugTag STEP 1 END: getRating() -> $rating');
    return rating;
  }

  /// ===== Teacher Rating: Get with Caching =====
  Future<double> getTeacherRating(int teacherId) async {
    debugPrint(
      '$teacherDebugTag STEP 1 START: getTeacherRating(teacherId=$teacherId)',
    );

    final cached = _getTeacherRatingFromCache(teacherId);
    if (cached != null) {
      debugPrint(
        '$teacherDebugTag ✅ STEP 1.1 CACHE HIT: teacherId=$teacherId, rating=$cached',
      );
      return cached;
    }

    debugPrint(
      '$teacherDebugTag ⏭️  STEP 1.1 CACHE MISS: teacherId=$teacherId, fetching from API...',
    );

    final rating = await _fetchTeacherRatingFromAPI(teacherId);
    _cacheTeacherRating(teacherId, rating);

    debugPrint('$teacherDebugTag STEP 1 END: getTeacherRating() -> $rating');
    return rating;
  }

  /// ===== STEP 2: Fetch Rating from API =====
  /// Input: classId
  /// Process: Call /classes/{id}/average_rating
  /// Output: rating (double)
  /// Error: Return 0.0 on failure with logging
  Future<double> _fetchRatingFromAPI(int classId) async {
    debugPrint('$debugTag STEP 2 START: _fetchRatingFromAPI(classId=$classId)');

    try {
      debugPrint(
        '$debugTag STEP 2.1: Calling API GET /classes/$classId/average_rating',
      );

      final rating = await class_api.ClassInfo.fetchAverageRating(classId);

      if (rating == null) {
        debugPrint(
          '$debugTag ⚠️  STEP 2.2 API RETURNED NULL: classId=$classId, defaulting to 0.0',
        );
        return 0.0;
      }

      debugPrint(
        '$debugTag ✅ STEP 2.2 API SUCCESS: classId=$classId, rating=$rating',
      );
      debugPrint('$debugTag STEP 2 END: _fetchRatingFromAPI() -> $rating');
      return rating;
    } on ApiException catch (e) {
      debugPrint(
        '$debugTag ❌ STEP 2.3 API ERROR: classId=$classId, statusCode=${e.statusCode}, message=${e.body}',
      );
      debugPrint(
        '$debugTag STEP 2 END (ERROR): _fetchRatingFromAPI() -> 0.0 (default)',
      );
      return 0.0;
    } catch (e) {
      debugPrint(
        '$debugTag ❌ STEP 2.3 UNKNOWN ERROR: classId=$classId, error=$e',
      );
      debugPrint(
        '$debugTag STEP 2 END (ERROR): _fetchRatingFromAPI() -> 0.0 (default)',
      );
      return 0.0;
    }
  }

  Future<double> _fetchTeacherRatingFromAPI(int teacherId) async {
    debugPrint(
      '$teacherDebugTag STEP 2 START: _fetchTeacherRatingFromAPI(teacherId=$teacherId)',
    );

    try {
      debugPrint(
        '$teacherDebugTag STEP 2.1: Calling API GET /teachers/$teacherId/average_rating',
      );

      final rating = await teacher_api.Teacher.fetchAverageRating(teacherId);

      if (rating == null) {
        debugPrint(
          '$teacherDebugTag ⚠️  STEP 2.2 API RETURNED NULL: teacherId=$teacherId, defaulting to 0.0',
        );
        return 0.0;
      }

      debugPrint(
        '$teacherDebugTag ✅ STEP 2.2 API SUCCESS: teacherId=$teacherId, rating=$rating',
      );
      debugPrint(
        '$teacherDebugTag STEP 2 END: _fetchTeacherRatingFromAPI() -> $rating',
      );
      return rating;
    } on ApiException catch (e) {
      debugPrint(
        '$teacherDebugTag ❌ STEP 2.3 API ERROR: teacherId=$teacherId, statusCode=${e.statusCode}, message=${e.body}',
      );
      debugPrint(
        '$teacherDebugTag STEP 2 END (ERROR): _fetchTeacherRatingFromAPI() -> 0.0 (default)',
      );
      return 0.0;
    } catch (e) {
      debugPrint(
        '$teacherDebugTag ❌ STEP 2.3 UNKNOWN ERROR: teacherId=$teacherId, error=$e',
      );
      debugPrint(
        '$teacherDebugTag STEP 2 END (ERROR): _fetchTeacherRatingFromAPI() -> 0.0 (default)',
      );
      return 0.0;
    }
  }

  /// ===== STEP 3: Get Rating from Cache =====
  /// Input: classId
  /// Process: Check if cache exists and not expired
  /// Output: rating (double?) or null if not cached/expired
  double? _getRatingFromCache(int classId) {
    debugPrint('$debugTag STEP 3 START: _getRatingFromCache(classId=$classId)');

    if (!_ratingCache.containsKey(classId)) {
      debugPrint('$debugTag STEP 3.1 NOT IN CACHE: classId=$classId');
      debugPrint('$debugTag STEP 3 END: _getRatingFromCache() -> null');
      return null;
    }

    final entry = _ratingCache[classId]!;
    debugPrint(
      '$debugTag STEP 3.2 FOUND IN CACHE: classId=$classId, rating=${entry.rating}',
    );

    // STEP 3.3: Check if expired
    final isExpired = DateTime.now().difference(entry.cachedAt) > cacheTtl;
    if (isExpired) {
      debugPrint(
        '$debugTag STEP 3.3 CACHE EXPIRED: classId=$classId, cachedAt=${entry.cachedAt}, now=${DateTime.now()}',
      );
      _ratingCache.remove(classId);
      debugPrint(
        '$debugTag STEP 3 END: _getRatingFromCache() -> null (expired)',
      );
      return null;
    }

    debugPrint('$debugTag ✅ STEP 3.3 CACHE VALID: classId=$classId');
    debugPrint(
      '$debugTag STEP 3 END: _getRatingFromCache() -> ${entry.rating}',
    );
    return entry.rating;
  }

  double? _getTeacherRatingFromCache(int teacherId) {
    debugPrint(
      '$teacherDebugTag STEP 3 START: _getTeacherRatingFromCache(teacherId=$teacherId)',
    );

    if (!_teacherRatingCache.containsKey(teacherId)) {
      debugPrint(
        '$teacherDebugTag STEP 3.1 NOT IN CACHE: teacherId=$teacherId',
      );
      debugPrint(
        '$teacherDebugTag STEP 3 END: _getTeacherRatingFromCache() -> null',
      );
      return null;
    }

    final entry = _teacherRatingCache[teacherId]!;
    debugPrint(
      '$teacherDebugTag STEP 3.2 FOUND IN CACHE: teacherId=$teacherId, rating=${entry.rating}',
    );

    final isExpired = DateTime.now().difference(entry.cachedAt) > cacheTtl;
    if (isExpired) {
      debugPrint(
        '$teacherDebugTag STEP 3.3 CACHE EXPIRED: teacherId=$teacherId, cachedAt=${entry.cachedAt}',
      );
      _teacherRatingCache.remove(teacherId);
      debugPrint(
        '$teacherDebugTag STEP 3 END: _getTeacherRatingFromCache() -> null (expired)',
      );
      return null;
    }

    debugPrint('$teacherDebugTag ✅ STEP 3.3 CACHE VALID: teacherId=$teacherId');
    debugPrint(
      '$teacherDebugTag STEP 3 END: _getTeacherRatingFromCache() -> ${entry.rating}',
    );
    return entry.rating;
  }

  /// ===== STEP 4: Cache Rating =====
  /// Input: classId, rating
  /// Process: Store in memory cache with timestamp
  void _cacheRating(int classId, double rating) {
    debugPrint(
      '$debugTag STEP 4 START: _cacheRating(classId=$classId, rating=$rating)',
    );

    _ratingCache[classId] = RatingCacheEntry(
      rating: rating,
      cachedAt: DateTime.now(),
    );

    debugPrint('$debugTag ✅ STEP 4 END: _cacheRating() stored in cache');
  }

  void _cacheTeacherRating(int teacherId, double rating) {
    debugPrint(
      '$teacherDebugTag STEP 4 START: _cacheTeacherRating(teacherId=$teacherId, rating=$rating)',
    );

    _teacherRatingCache[teacherId] = RatingCacheEntry(
      rating: rating,
      cachedAt: DateTime.now(),
    );

    debugPrint(
      '$teacherDebugTag ✅ STEP 4 END: _cacheTeacherRating() stored in cache',
    );
  }

  /// ===== STEP 5: Refresh Rating (Force) =====
  /// Input: classId
  /// Process: Skip cache, fetch from API, update cache
  /// Output: rating (double)
  Future<double> refreshRating(int classId) async {
    debugPrint(
      '$debugTag STEP 5 START: refreshRating(classId=$classId) - FORCE REFRESH',
    );

    // Remove from cache to force fresh fetch
    _ratingCache.remove(classId);
    debugPrint('$debugTag STEP 5.1 CACHE CLEARED: classId=$classId');

    final rating = await _fetchRatingFromAPI(classId);
    _cacheRating(classId, rating);

    debugPrint('$debugTag ✅ STEP 5 END: refreshRating() -> $rating');
    return rating;
  }

  Future<double> refreshTeacherRating(int teacherId) async {
    debugPrint(
      '$teacherDebugTag STEP 5 START: refreshTeacherRating(teacherId=$teacherId) - FORCE REFRESH',
    );

    _teacherRatingCache.remove(teacherId);
    debugPrint('$teacherDebugTag STEP 5.1 CACHE CLEARED: teacherId=$teacherId');

    final rating = await _fetchTeacherRatingFromAPI(teacherId);
    _cacheTeacherRating(teacherId, rating);

    debugPrint(
      '$teacherDebugTag ✅ STEP 5 END: refreshTeacherRating() -> $rating',
    );
    return rating;
  }

  /// ===== STEP 6: Batch Get Ratings =====
  /// Input: List of classId
  /// Process: Get rating for each classId (with cache)
  /// Output: Map of classId to rating
  Future<Map<int, double>> getRatings(List<int> classIds) async {
    debugPrint('$debugTag STEP 6 START: getRatings(classIds=$classIds)');

    final result = <int, double>{};

    for (final classId in classIds) {
      debugPrint('$debugTag STEP 6.1 PROCESSING: classId=$classId');
      final rating = await getRating(classId);
      result[classId] = rating;
    }

    debugPrint('$debugTag ✅ STEP 6 END: getRatings() -> $result');
    return result;
  }

  /// ===== STEP 7: Clear Cache =====
  /// Input: optional classId (if null, clear all)
  /// Process: Remove from cache
  void clearCache({int? classId}) {
    if (classId != null) {
      debugPrint('$debugTag STEP 7 START: clearCache(classId=$classId)');
      _ratingCache.remove(classId);
      debugPrint('$debugTag ✅ STEP 7 END: Cache cleared for classId=$classId');
    } else {
      debugPrint('$debugTag STEP 7 START: clearCache() - CLEAR ALL');
      final count = _ratingCache.length;
      _ratingCache.clear();
      debugPrint(
        '$debugTag ✅ STEP 7 END: Cache cleared, removed $count entries',
      );
    }
  }

  void clearTeacherCache({int? teacherId}) {
    if (teacherId != null) {
      debugPrint(
        '$teacherDebugTag STEP 7 START: clearTeacherCache(teacherId=$teacherId)',
      );
      _teacherRatingCache.remove(teacherId);
      debugPrint(
        '$teacherDebugTag ✅ STEP 7 END: Cache cleared for teacherId=$teacherId',
      );
    } else {
      debugPrint(
        '$teacherDebugTag STEP 7 START: clearTeacherCache() - CLEAR ALL',
      );
      final count = _teacherRatingCache.length;
      _teacherRatingCache.clear();
      debugPrint(
        '$teacherDebugTag ✅ STEP 7 END: Cache cleared, removed $count entries',
      );
    }
  }

  /// ===== DEBUG: Print Cache Status =====
  void printCacheStatus() {
    debugPrint('$debugTag ===== CACHE STATUS =====');
    debugPrint('$debugTag Total cached entries: ${_ratingCache.length}');
    debugPrint(
      '$teacherDebugTag Total cached entries: ${_teacherRatingCache.length}',
    );
    debugPrint('$debugTag Cache TTL: $cacheTtl');

    if (_ratingCache.isEmpty) {
      debugPrint('$debugTag Cache is empty');
    } else {
      _ratingCache.forEach((classId, entry) {
        final age = DateTime.now().difference(entry.cachedAt);
        final isExpired = age > cacheTtl;
        debugPrint(
          '$debugTag  - classId=$classId, rating=${entry.rating}, age=${age.inSeconds}s, expired=$isExpired',
        );
      });
    }

    if (_teacherRatingCache.isEmpty) {
      debugPrint('$teacherDebugTag Cache is empty');
    } else {
      _teacherRatingCache.forEach((teacherId, entry) {
        final age = DateTime.now().difference(entry.cachedAt);
        final isExpired = age > cacheTtl;
        debugPrint(
          '$teacherDebugTag  - teacherId=$teacherId, rating=${entry.rating}, age=${age.inSeconds}s, expired=$isExpired',
        );
      });
    }

    debugPrint('$debugTag ========================');
  }

  /// ===== DEBUG: Get Cache Info =====
  Map<String, dynamic> getCacheInfo() {
    return {
      'total_entries': _ratingCache.length,
      'cache_ttl_minutes': cacheTtl.inMinutes,
      'entries': _ratingCache.entries
          .map(
            (e) => {
              'class_id': e.key,
              'rating': e.value.rating,
              'cached_at': e.value.cachedAt.toIso8601String(),
              'age_seconds': DateTime.now()
                  .difference(e.value.cachedAt)
                  .inSeconds,
              'is_expired':
                  DateTime.now().difference(e.value.cachedAt) > cacheTtl,
            },
          )
          .toList(),
      'teacher_total_entries': _teacherRatingCache.length,
      'teacher_entries': _teacherRatingCache.entries
          .map(
            (e) => {
              'teacher_id': e.key,
              'rating': e.value.rating,
              'cached_at': e.value.cachedAt.toIso8601String(),
              'age_seconds': DateTime.now()
                  .difference(e.value.cachedAt)
                  .inSeconds,
              'is_expired':
                  DateTime.now().difference(e.value.cachedAt) > cacheTtl,
            },
          )
          .toList(),
    };
  }
}

/// Cache entry for rating
class RatingCacheEntry {
  final double rating;
  final DateTime cachedAt;

  RatingCacheEntry({required this.rating, required this.cachedAt});

  @override
  String toString() => 'RatingCacheEntry(rating=$rating, cachedAt=$cachedAt)';
}
