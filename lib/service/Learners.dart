import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class Learner {
  final int flagCount;
  final int userId;

  Learner({required this.flagCount, required this.userId});

  factory Learner.fromJson(Map<String, dynamic> json) {
    return Learner(flagCount: json['flag_count'], userId: json['user_id']);
  }

  Map<String, dynamic> toJson() {
    return {'flag_count': flagCount, 'user_id': userId};
  }

  // ---------- CRUD ----------

  /// GET /learners (200, 500)
  static Future<List<Learner>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/learners"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Learner.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch learners (code: ${res.statusCode})");
    }
  }

  /// GET /learners/:id (200, 400, 404, 500)
  static Future<Learner> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/learners/$id"));
    switch (res.statusCode) {
      case 200:
        return Learner.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Learner not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch learner $id (code: ${res.statusCode})",
        );
    }
  }

  /// POST /learners (201, 400, 500)
  static Future<Learner> create(Learner learner) async {
    final res = await http.post(
      ApiService.endpoint("/learners"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(learner.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return Learner.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to create learner (code: ${res.statusCode})");
    }
  }

  /// DELETE /learners/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/learners/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Learner not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to delete learner $id (code: ${res.statusCode})",
        );
    }
  }
}
