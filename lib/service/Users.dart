import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class User {
  final int id;
  final String? studentId;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? phoneNumber;
  final double balance;
  final int banCount;
  final String? profilePicture;
  final Teacher? teacher;
  final Learner? learner;

  User({
    required this.id,
    this.studentId,
    this.firstName,
    this.lastName,
    this.gender,
    this.phoneNumber,
    required this.balance,
    required this.banCount,
    this.profilePicture,
    this.teacher,
    this.learner,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json["ID"] ?? json["id"],
      studentId: json["student_id"],
      firstName: json["first_name"],
      lastName: json["last_name"],
      gender: json["gender"],
      phoneNumber: json["phone_number"],
      balance: _parseBalance(json["balance"]),
      banCount: json["ban_count"] ?? 0,
      profilePicture: json["profile_picture"],
      teacher: json["Teacher"] != null
          ? Teacher.fromJson(json["Teacher"])
          : null,
      learner: json["Learner"] != null
          ? Learner.fromJson(json["Learner"])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "student_id": studentId,
      "first_name": firstName,
      "last_name": lastName,
      "gender": gender,
      "phone_number": phoneNumber,
      "balance": balance,
      "ban_count": banCount,
      "profile_picture": profilePicture,
    };
  }

  // ---------- CRUD ----------

  /// GET /users (200)
  static Future<List<User>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/users"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => User.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch users (code: ${res.statusCode})");
    }
  }

  /// GET /users/:id (200, 400, 404, 500)
  static Future<User> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/users/$id"));
    switch (res.statusCode) {
      case 200:
        return User.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("User not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch user $id (code: ${res.statusCode})");
    }
  }

  /// POST /users (201, 400, 500)
  static Future<User> create(User user) async {
    final res = await http.post(
      ApiService.endpoint("/users"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(user.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return User.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to create user (code: ${res.statusCode})");
    }
  }

  /// PUT /users/:id (200, 400, 404, 500)
  static Future<User> update(int id, User user) async {
    final res = await http.put(
      ApiService.endpoint("/users/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(user.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return User.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("User not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to update user $id (code: ${res.statusCode})");
    }
  }

  /// DELETE /users/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/users/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("User not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to delete user $id (code: ${res.statusCode})");
    }
  }
}

class Teacher {
  final int id;
  final int userId;
  final String? description;
  final int? flagCount;
  final String? email;

  Teacher({
    required this.id,
    required this.userId,
    this.description,
    this.flagCount,
    this.email,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json["ID"] ?? json["id"],
      userId: json["user_id"],
      description: json["description"],
      flagCount: json["flag_count"],
      email: json["email"],
    );
  }
}

class Learner {
  final int id;
  final int userId;
  final int? flagCount;

  Learner({required this.id, required this.userId, this.flagCount});

  factory Learner.fromJson(Map<String, dynamic> json) {
    return Learner(
      id: json["ID"] ?? json["id"],
      userId: json["user_id"],
      flagCount: json["flag_count"],
    );
  }
}

double _parseBalance(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}
