import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _userIdKey = 'user_id';
  static const String _tokenKey = 'token';
  static const String _userBalanceKey = 'user_balance';
  static const String _learnerIdKey = 'learner_id';
  static const String _userProfileKey = 'user_profile';

  /// Save user ID to local storage
  static Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  /// Get user ID from local storage
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  /// Save token to local storage
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Get token from local storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Save current user balance to local storage
  static Future<void> saveUserBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_userBalanceKey, balance);
  }

  /// Read cached user balance (if available)
  static Future<double?> getUserBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_userBalanceKey);
  }

  /// Save learner id for enrollment operations
  static Future<void> saveLearnerId(int learnerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_learnerIdKey, learnerId);
  }

  /// Get cached learner id
  static Future<int?> getLearnerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_learnerIdKey);
  }

  /// Clear all stored data (for logout)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Remove user ID
  static Future<void> removeUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
  }

  /// Remove token
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Persist user profile json (used for restoring cache on cold start)
  static Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileKey, jsonEncode(profile));
  }

  /// Read cached user profile json if available
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userProfileKey);
    if (jsonStr == null) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      return decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      return null;
    }
  }

  /// Remove cached user profile
  static Future<void> removeUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userProfileKey);
  }
}
