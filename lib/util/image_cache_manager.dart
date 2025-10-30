import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Image cache manager with memory and disk caching
class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();

  // Memory cache: URL -> Image bytes
  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Cache settings
  static const Duration _memoryTtl = Duration(minutes: 10);
  static const Duration _diskTtl = Duration(hours: 24);
  static const int _maxMemoryCacheSize = 50; // Max images in memory

  /// Get image from cache or fetch from network
  Future<Uint8List?> getImage(String url, {bool forceRefresh = false}) async {
    if (url.isEmpty) return null;

    final cacheKey = _getCacheKey(url);

    if (!forceRefresh) {
      // Check memory cache first
      final memoryImage = _getFromMemory(cacheKey);
      if (memoryImage != null) {
        debugPrint('🟢 [ImageCache] Memory hit: $url');
        return memoryImage;
      }

      // Check disk cache
      final diskImage = await _getFromDisk(cacheKey);
      if (diskImage != null) {
        debugPrint('🟢 [ImageCache] Disk hit: $url');
        _saveToMemory(cacheKey, diskImage);
        return diskImage;
      }
    }

    // Fetch from network
    debugPrint('🔄 [ImageCache] Fetching: $url');
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await _saveToDisk(cacheKey, bytes);
        _saveToMemory(cacheKey, bytes);
        debugPrint('💾 [ImageCache] Cached: $url');
        return bytes;
      } else {
        debugPrint('⚠️ [ImageCache] HTTP ${response.statusCode}: $url');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ [ImageCache] Fetch error: $e');
      return null;
    }
  }

  /// Prefetch multiple images in background
  Future<void> prefetchImages(List<String> urls) async {
    for (final url in urls) {
      if (url.isEmpty) continue;

      final cacheKey = _getCacheKey(url);

      // Skip if already in memory cache
      if (_getFromMemory(cacheKey) != null) {
        continue;
      }

      // Fetch without blocking
      getImage(url).catchError((e) {
        debugPrint('⚠️ [ImageCache] Prefetch failed for $url: $e');
        return null;
      });
    }
  }

  /// Clear old cache entries
  Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final imageKeys = keys.where((k) => k.startsWith('img_cache:'));

      int cleared = 0;
      for (final key in imageKeys) {
        final timestamp = prefs.getInt('${key}_time');
        if (timestamp == null) {
          await prefs.remove(key);
          cleared++;
          continue;
        }

        final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cachedAt) > _diskTtl) {
          await prefs.remove(key);
          await prefs.remove('${key}_time');
          cleared++;
        }
      }

      if (cleared > 0) {
        debugPrint('🗑️ [ImageCache] Cleared $cleared expired entries');
      }
    } catch (e) {
      debugPrint('⚠️ [ImageCache] Clear error: $e');
    }
  }

  /// Clear all image cache
  Future<void> clearAll() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final imageKeys = keys.where((k) => k.startsWith('img_cache:'));

      for (final key in imageKeys) {
        await prefs.remove(key);
        await prefs.remove('${key}_time');
      }

      debugPrint('🗑️ [ImageCache] Cleared all cache');
    } catch (e) {
      debugPrint('⚠️ [ImageCache] Clear all error: $e');
    }
  }

  // Private methods

  String _getCacheKey(String url) {
    return 'img_cache:${url.hashCode}';
  }

  Uint8List? _getFromMemory(String cacheKey) {
    if (!_memoryCache.containsKey(cacheKey)) return null;

    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return null;

    final age = DateTime.now().difference(timestamp);
    if (age > _memoryTtl) {
      _memoryCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      return null;
    }

    return _memoryCache[cacheKey];
  }

  void _saveToMemory(String cacheKey, Uint8List bytes) {
    // Limit memory cache size (FIFO)
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _memoryCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }

    _memoryCache[cacheKey] = bytes;
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  Future<Uint8List?> _getFromDisk(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('${cacheKey}_time');
      if (timestamp == null) return null;

      final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cachedAt);
      if (age > _diskTtl) {
        await prefs.remove(cacheKey);
        await prefs.remove('${cacheKey}_time');
        return null;
      }

      final base64Str = prefs.getString(cacheKey);
      if (base64Str == null) return null;

      // Decode from base64
      return Uint8List.fromList(base64Str.codeUnits);
    } catch (e) {
      debugPrint('⚠️ [ImageCache] Disk read error: $e');
      return null;
    }
  }

  Future<void> _saveToDisk(String cacheKey, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Store as base64 string (SharedPreferences doesn't support binary)
      final base64Str = String.fromCharCodes(bytes);
      await prefs.setString(cacheKey, base64Str);
      await prefs.setInt(
        '${cacheKey}_time',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('⚠️ [ImageCache] Disk write error: $e');
    }
  }
}
