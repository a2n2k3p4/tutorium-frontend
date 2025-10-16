import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class Enrollment {
  final int classSessionId;
  final String enrollmentStatus;
  final int learnerId;

  Enrollment({
    required this.classSessionId,
    required this.enrollmentStatus,
    required this.learnerId,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    return Enrollment(
      classSessionId: json['class_session_id'],
      enrollmentStatus: json['enrollment_status'] ?? '',
      learnerId: json['learner_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_session_id': classSessionId,
      'enrollment_status': enrollmentStatus,
      'learner_id': learnerId,
    };
  }

  // ---------- CRUD ----------

  /// GET /enrollments (200, 500)
  static Future<List<Enrollment>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/enrollments"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Enrollment.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch enrollments (code: ${res.statusCode})",
        );
    }
  }

  /// GET /enrollments/:id (200, 400, 404, 500)
  static Future<Enrollment> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/enrollments/$id"));
    switch (res.statusCode) {
      case 200:
        return Enrollment.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Enrollment not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch enrollment $id (code: ${res.statusCode})",
        );
    }
  }

  /// POST /enrollments (201, 400, 500)
  static Future<Enrollment> create(Enrollment enrollment) async {
    final res = await http.post(
      ApiService.endpoint("/enrollments"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(enrollment.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return Enrollment.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to create enrollment (code: ${res.statusCode})",
        );
    }
  }

  /// PUT /enrollments/:id (200, 400, 404, 500)
  static Future<Enrollment> update(int id, Enrollment enrollment) async {
    final res = await http.put(
      ApiService.endpoint("/enrollments/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(enrollment.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return Enrollment.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("Enrollment not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to update enrollment $id (code: ${res.statusCode})",
        );
    }
  }

  /// DELETE /enrollments/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/enrollments/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Enrollment not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to delete enrollment $id (code: ${res.statusCode})",
        );
    }
  }
}
