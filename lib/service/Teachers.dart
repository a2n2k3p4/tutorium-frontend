import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class Teacher {
  final String description;
  final String email;
  final int flagCount;
  final int userId;

  Teacher({
    required this.description,
    required this.email,
    required this.flagCount,
    required this.userId,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      description: json['description'] ?? '',
      email: json['email'] ?? '',
      flagCount: json['flag_count'],
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'email': email,
      'flag_count': flagCount,
      'user_id': userId,
    };
  }

  // ---------- CRUD ----------

  /// GET /teachers (200, 500)
  static Future<List<Teacher>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/teachers"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Teacher.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch teachers (code: ${res.statusCode})");
    }
  }

  /// POST /teachers (201, 400, 500)
  static Future<Teacher> create(Teacher teacher) async {
    final res = await http.post(
      ApiService.endpoint("/teachers"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(teacher.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return Teacher.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to create teacher (code: ${res.statusCode})");
    }
  }

  /// GET /teachers/:id (200, 400, 404, 500)
  static Future<Teacher> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/teachers/$id"));
    switch (res.statusCode) {
      case 200:
        return Teacher.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Teacher not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch teacher $id (code: ${res.statusCode})",
        );
    }
  }

  /// PUT /teachers/:id (200, 400, 404, 500)
  static Future<Teacher> update(int id, Teacher teacher) async {
    final res = await http.put(
      ApiService.endpoint("/teachers/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(teacher.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return Teacher.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("Teacher not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to update teacher $id (code: ${res.statusCode})",
        );
    }
  }

  /// DELETE /teachers/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/teachers/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Teacher not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to delete teacher $id (code: ${res.statusCode})",
        );
    }
  }
}
