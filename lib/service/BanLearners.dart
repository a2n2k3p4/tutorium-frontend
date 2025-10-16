import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class BanLearner {
  final String banDescription;
  final String banEnd;
  final String banStart;
  final int learnerId;

  BanLearner({
    required this.banDescription,
    required this.banEnd,
    required this.banStart,
    required this.learnerId,
  });

  factory BanLearner.fromJson(Map<String, dynamic> json) {
    return BanLearner(
      banDescription: json["ban_description"],
      banEnd: json["ban_end"],
      banStart: json["ban_start"],
      learnerId: json["learner_id"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "ban_description": banDescription,
      "ban_end": banEnd,
      "ban_start": banStart,
      "learner_id": learnerId,
    };
  }

  // ---------- CRUD ----------

  /// GET /banlearners (200)
  static Future<List<BanLearner>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/banlearners"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => BanLearner.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch banned learners (code: ${res.statusCode})",
        );
    }
  }

  /// GET /banlearners/:id (200, 400, 404, 500)
  static Future<BanLearner> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/banlearners/$id"));
    switch (res.statusCode) {
      case 200:
        return BanLearner.fromJson(jsonDecode(res.body));
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

  /// POST /banlearners (201, 400, 500)
  static Future<BanLearner> create(BanLearner ban) async {
    final res = await http.post(
      ApiService.endpoint("/banlearners"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(ban.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return BanLearner.fromJson(jsonDecode(res.body));
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

  /// PUT /banlearners/:id (200, 400, 404, 500)
  static Future<BanLearner> update(int id, BanLearner ban) async {
    final res = await http.put(
      ApiService.endpoint("/banlearners/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(ban.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return BanLearner.fromJson(jsonDecode(res.body));
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

  /// DELETE /banlearners/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/banlearners/$id"));
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
