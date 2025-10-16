import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class BanTeacher {
  final String banDescription;
  final String banEnd;
  final String banStart;
  final int teacherId;

  BanTeacher({
    required this.banDescription,
    required this.banEnd,
    required this.banStart,
    required this.teacherId,
  });

  factory BanTeacher.fromJson(Map<String, dynamic> json) {
    return BanTeacher(
      banDescription: json["ban_description"],
      banEnd: json["ban_end"],
      banStart: json["ban_start"],
      teacherId: json["teacher_id"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "ban_description": banDescription,
      "ban_end": banEnd,
      "ban_start": banStart,
      "teacher_id": teacherId,
    };
  }

  // ---------- CRUD ----------

  /// GET /banteachers (200)
  static Future<List<BanTeacher>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/banteachers"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => BanTeacher.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch banned teachers (code: ${res.statusCode})",
        );
    }
  }

  /// GET /banteachers/:id (200, 400, 404, 500)
  static Future<BanTeacher> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/banteachers/$id"));
    switch (res.statusCode) {
      case 200:
        return BanTeacher.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Ban record not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch ban record $id (code: ${res.statusCode})",
        );
    }
  }

  /// POST /banteachers (201, 400, 500)
  static Future<BanTeacher> create(BanTeacher ban) async {
    final res = await http.post(
      ApiService.endpoint("/banteachers"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(ban.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return BanTeacher.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to create ban record (code: ${res.statusCode})",
        );
    }
  }

  /// PUT /banteachers/:id (200, 400, 404, 500)
  static Future<BanTeacher> update(int id, BanTeacher ban) async {
    final res = await http.put(
      ApiService.endpoint("/banteachers/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(ban.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return BanTeacher.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("Ban record not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to update ban record $id (code: ${res.statusCode})",
        );
    }
  }

  /// DELETE /banteachers/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/banteachers/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Ban record not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to delete ban record $id (code: ${res.statusCode})",
        );
    }
  }
}
