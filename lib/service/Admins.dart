import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class Admin {
  final int id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int userId;

  Admin({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.userId,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json["ID"],
      createdAt: json["CreatedAt"],
      updatedAt: json["UpdatedAt"],
      deletedAt: json["DeletedAt"],
      userId: json["user_id"],
    );
  }

  /// สำหรับ POST /admins (รับแค่ user_id)
  Map<String, dynamic> toJson() {
    return {"user_id": userId};
  }

  /// GET /admins (200)
  static Future<List<Admin>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/admins"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Admin.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch admins (code: ${res.statusCode})");
    }
  }

  /// GET /admins/:id (200, 400, 404, 500)
  static Future<Admin> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/admins/$id"));
    switch (res.statusCode) {
      case 200:
        return Admin.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Admin not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch admin $id (code: ${res.statusCode})");
    }
  }

  /// POST /admins (201, 400, 500)
  static Future<Admin> create(int userId) async {
    final res = await http.post(
      ApiService.endpoint("/admins"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"user_id": userId}),
    );
    switch (res.statusCode) {
      case 201:
        return Admin.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to create admin (code: ${res.statusCode})");
    }
  }

  /// DELETE /admins/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/admins/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Admin not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to delete admin $id (code: ${res.statusCode})");
    }
  }
}
