import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager with extended cache duration and larger size
class CustomCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'tutoriumCachedData';

  static CustomCacheManager? _instance;

  factory CustomCacheManager() {
    _instance ??= CustomCacheManager._();
    return _instance!;
  }

  CustomCacheManager._()
    : super(
        Config(
          key,
          // Cache for 90 days (3 months)
          stalePeriod: const Duration(days: 90),
          // Maximum 5000 cached objects
          maxNrOfCacheObjects: 5000,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ),
      );
}

/// Cache manager for class images with even longer duration
class ClassImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'tutoriumClassImages';

  static ClassImageCacheManager? _instance;

  factory ClassImageCacheManager() {
    _instance ??= ClassImageCacheManager._();
    return _instance!;
  }

  ClassImageCacheManager._()
    : super(
        Config(
          key,
          // Cache images for 180 days (6 months)
          stalePeriod: const Duration(days: 180),
          // Maximum 10000 cached images
          maxNrOfCacheObjects: 10000,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ),
      );
}

/// Cache manager for user profile images
class ProfileImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'tutoriumProfileImages';

  static ProfileImageCacheManager? _instance;

  factory ProfileImageCacheManager() {
    _instance ??= ProfileImageCacheManager._();
    return _instance!;
  }

  ProfileImageCacheManager._()
    : super(
        Config(
          key,
          // Cache profile images for 30 days
          stalePeriod: const Duration(days: 30),
          // Maximum 2000 cached profile images
          maxNrOfCacheObjects: 2000,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ),
      );
}
