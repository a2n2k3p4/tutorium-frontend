import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class ClassInfo {
  final String bannerPicture;
  final String classDescription;
  final String className;
  final double rating;
  final int teacherId;

  ClassInfo({
    required this.bannerPicture,
    required this.classDescription,
    required this.className,
    required this.rating,
    required this.teacherId,
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    return ClassInfo(
      bannerPicture: json['banner_picture'] ?? json['banner_picture_url'] ?? '',
      classDescription: json['class_description'] ?? '',
      className: json['class_name'] ?? '',
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : double.tryParse('${json['rating']}') ?? 0,
      teacherId: json['teacher_id'] ?? json['Teacher']?['user_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'banner_picture': bannerPicture,
      'class_description': classDescription,
      'class_name': className,
      'rating': rating,
      'teacher_id': teacherId,
    };
  }

  // ---------- CRUD ----------

  /// GET /classes (200, 400, 500)
  static Future<List<ClassInfo>> fetchAll({
    List<String>? categories,
    double? minRating,
    double? maxRating,
  }) async {
    final queryParams = <String, dynamic>{};
    if (categories != null && categories.isNotEmpty) {
      queryParams['category'] = categories;
    }
    if (minRating != null) {
      queryParams['min_rating'] = minRating.toString();
    }
    if (maxRating != null) {
      queryParams['max_rating'] = maxRating.toString();
    }
    final uri = Uri(
      scheme: ApiService.endpoint("/classes").scheme,
      host: ApiService.endpoint("/classes").host,
      port: ApiService.endpoint("/classes").port,
      path: ApiService.endpoint("/classes").path,
      queryParameters: queryParams.isNotEmpty
          ? queryParams.map((k, v) => MapEntry(k, v is List ? v : v.toString()))
          : null,
    );
    final res = await http.get(uri);
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => ClassInfo.fromJson(e)).toList();
      case 400:
        throw Exception("Invalid query parameters: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch classes (code: ${res.statusCode})");
    }
  }

  /// GET /classes/:id (200, 400, 404, 500)
  static Future<ClassInfo> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/classes/$id"));
    switch (res.statusCode) {
      case 200:
        return ClassInfo.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Class not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch class $id (code: ${res.statusCode})");
    }
  }

  /// POST /classes (201, 400, 500)
  static Future<ClassInfo> create(ClassInfo info) async {
    final res = await http.post(
      ApiService.endpoint("/classes"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(info.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return ClassInfo.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to create class (code: ${res.statusCode})");
    }
  }

  /// PUT /classes/:id (200, 400, 404, 500)
  static Future<ClassInfo> update(int id, ClassInfo info) async {
    final res = await http.put(
      ApiService.endpoint("/classes/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(info.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return ClassInfo.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("Class not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to update class $id (code: ${res.statusCode})");
    }
  }

  /// DELETE /classes/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/classes/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Class not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to delete class $id (code: ${res.statusCode})");
    }
  }
}
