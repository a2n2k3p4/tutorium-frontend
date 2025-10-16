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
      bannerPicture: json["banner_picture"],
      classDescription: json["class_description"],
      className: json["class_name"],
      rating: (json["rating"] as num).toDouble(),
      teacherId: json["teacher_id"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "banner_picture": bannerPicture,
      "class_description": classDescription,
      "class_name": className,
      "rating": rating,
      "teacher_id": teacherId,
    };
  }
}

class ClassCategory {
  final String classCategory;
  final List<ClassInfo> classes;

  ClassCategory({required this.classCategory, required this.classes});

  factory ClassCategory.fromJson(Map<String, dynamic> json) {
    return ClassCategory(
      classCategory: json["class_category"],
      classes: (json["classes"] as List<dynamic>)
          .map((e) => ClassInfo.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "class_category": classCategory,
      "classes": classes.map((e) => e.toJson()).toList(),
    };
  }

  // ---------- CRUD ----------

  /// GET /class_categories (200)
  static Future<List<ClassCategory>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/class_categories"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => ClassCategory.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch class categories (code: ${res.statusCode})",
        );
    }
  }

  /// GET /class_categories/:id (200, 400, 404, 500)
  static Future<ClassCategory> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/class_categories/$id"));
    switch (res.statusCode) {
      case 200:
        return ClassCategory.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Class category not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch class category $id (code: ${res.statusCode})",
        );
    }
  }

  /// POST /class_categories (201, 400, 500)
  static Future<ClassCategory> create(ClassCategory category) async {
    final res = await http.post(
      ApiService.endpoint("/class_categories"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(category.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return ClassCategory.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to create class category (code: ${res.statusCode})",
        );
    }
  }

  /// PUT /class_categories/:id (200, 400, 404, 500)
  static Future<ClassCategory> update(int id, ClassCategory category) async {
    final res = await http.put(
      ApiService.endpoint("/class_categories/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(category.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return ClassCategory.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("Class category not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to update class category $id (code: ${res.statusCode})",
        );
    }
  }

  /// DELETE /class_categories/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/class_categories/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Class category not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to delete class category $id (code: ${res.statusCode})",
        );
    }
  }
}
