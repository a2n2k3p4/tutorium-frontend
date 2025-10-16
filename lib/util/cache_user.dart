import 'package:tutorium_frontend/service/Users.dart' as user_api;

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
  }

  /// Update user in cache
  void updateUser(user_api.User user) {
    _cachedUser = user;
  }

  /// Clear cache (called on logout)
  void clear() {
    _cachedUser = null;
  }

  /// Refresh user data from server
  Future<user_api.User> refresh(int userId) async {
    final user = await user_api.User.fetchById(userId);
    _cachedUser = user;
    return user;
  }

  /// Get user data (from cache or fetch if not available)
  Future<user_api.User> getUser(int userId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUser != null && _cachedUser!.id == userId) {
      return _cachedUser!;
    }
    return await refresh(userId);
  }
}
