import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class ClassSession {
  final int id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int classId;
  final String description;
  final double price;
  final int learnerLimit;
  final String enrollmentDeadline;
  final String classStart;
  final String classFinish;
  final String classStatus;
  final String classUrl;

  ClassSession({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.classId,
    required this.description,
    required this.price,
    required this.learnerLimit,
    required this.enrollmentDeadline,
    required this.classStart,
    required this.classFinish,
    required this.classStatus,
    required this.classUrl,
  });

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      id: json["ID"] ?? 0,
      createdAt: json["CreatedAt"] ?? "",
      updatedAt: json["UpdatedAt"] ?? "",
      deletedAt: json["DeletedAt"],
      classId: json["class_id"],
      description: json["description"],
      price: (json["price"] as num).toDouble(),
      learnerLimit: json["learner_limit"],
      enrollmentDeadline: json["enrollment_deadline"],
      classStart: json["class_start"],
      classFinish: json["class_finish"],
      classStatus: json["class_status"],
      classUrl: json["class_url"] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "class_id": classId,
      "description": description,
      "price": price,
      "learner_limit": learnerLimit,
      "enrollment_deadline": enrollmentDeadline,
      "class_start": classStart,
      "class_finish": classFinish,
      "class_status": classStatus,
      // "class_url": classUrl, // ไม่ต้องส่งตอน create
    };
  }

  // ---------- CRUD ----------

  /// GET /class_sessions (200)
  static Future<List<ClassSession>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/class_sessions"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => ClassSession.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch class sessions (code: ${res.statusCode})",
        );
    }
  }

  /// GET /class_sessions/:id (200, 400, 404, 500)
  static Future<ClassSession> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/class_sessions/$id"));
    switch (res.statusCode) {
      case 200:
        return ClassSession.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Class session not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch class session $id (code: ${res.statusCode})",
        );
    }
  }

  /// POST /class_sessions (201, 400, 500)
  static Future<ClassSession> create(ClassSession session) async {
    final res = await http.post(
      ApiService.endpoint("/class_sessions"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(session.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return ClassSession.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to create class session (code: ${res.statusCode})",
        );
    }
  }

  /// PUT /class_sessions/:id (200, 400, 404, 500)
  static Future<ClassSession> update(int id, ClassSession session) async {
    final res = await http.put(
      ApiService.endpoint("/class_sessions/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(session.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return ClassSession.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("Class session not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to update class session $id (code: ${res.statusCode})",
        );
    }
  }

  /// DELETE /class_sessions/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/class_sessions/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Class session not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to delete class session $id (code: ${res.statusCode})",
        );
    }
  }
}
