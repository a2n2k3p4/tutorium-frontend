import 'package:tutorium_frontend/service/Users.dart' as user_api;
import 'package:tutorium_frontend/util/local_storage.dart';

/// UserCache - Singleton class for caching user data
class UserCache {
  // Singleton instance
  static final UserCache _instance = UserCache._internal();

  factory UserCache() => _instance;

  UserCache._internal();

  // Cached user data
  user_api.User? _cachedUser;

  /// Get cached user data
  user_api.User? get user => _cachedUser;

  /// Check if user is cached
  bool get hasUser => _cachedUser != null;

  /// Save user to cache (called after login or update)
  void saveUser(user_api.User user) {
    _cachedUser = user;
    LocalStorage.saveUserProfile(_userToCacheJson(user));
  }

  /// Update user in cache
  void updateUser(user_api.User user) {
    _cachedUser = user;
    LocalStorage.saveUserProfile(_userToCacheJson(user));
  }

  /// Clear cache (called on logout)
  void clear() {
    _cachedUser = null;
    LocalStorage.removeUserProfile();
  }

  /// Refresh user data from server
  Future<user_api.User> refresh(int userId) async {
    final user = await user_api.User.fetchById(userId);
    _cachedUser = user;
    LocalStorage.saveUserProfile(_userToCacheJson(user));
    return user;
  }

  /// Get user data (from cache or fetch if not available)
  Future<user_api.User> getUser(int userId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      if (_cachedUser != null && _cachedUser!.id == userId) {
        return _cachedUser!;
      }
      final restored = await _restoreFromLocal();
      if (restored != null && restored.id == userId) {
        return restored;
      }
    }
    return await refresh(userId);
  }

  Future<user_api.User?> _restoreFromLocal() async {
    final jsonMap = await LocalStorage.getUserProfile();
    if (jsonMap == null) return null;
    try {
      final user = user_api.User.fromJson(jsonMap);
      _cachedUser = user;
      return user;
    } catch (e) {
      return null;
    }
  }
}

Map<String, dynamic> _userToCacheJson(user_api.User user) {
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
