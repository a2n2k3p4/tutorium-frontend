import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class Review {
  final int classId;
  final String comment;
  final int learnerId;
  final int rating;

  Review({
    required this.classId,
    required this.comment,
    required this.learnerId,
    required this.rating,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      classId: json['class_id'],
      comment: json['comment'] ?? '',
      learnerId: json['learner_id'],
      rating: json['rating'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'comment': comment,
      'learner_id': learnerId,
      'rating': rating,
    };
  }

  // ---------- CRUD ----------

  /// GET /reviews (200, 500)
  static Future<List<Review>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/reviews"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Review.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch reviews (code: ${res.statusCode})");
    }
  }

  /// GET /reviews/:id (200, 400, 404, 500)
  static Future<Review> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/reviews/$id"));
    switch (res.statusCode) {
      case 200:
        return Review.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Review not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch review $id (code: ${res.statusCode})");
    }
  }

  /// POST /reviews (201, 400, 500)
  static Future<Review> create(Review review) async {
    final res = await http.post(
      ApiService.endpoint("/reviews"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(review.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return Review.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input or rating out of range: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to create review (code: ${res.statusCode})");
    }
  }

  /// PUT /reviews/:id (200, 400, 404, 500)
  static Future<Review> update(int id, Review review) async {
    final res = await http.put(
      ApiService.endpoint("/reviews/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(review.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return Review.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("Review not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to update review $id (code: ${res.statusCode})",
        );
    }
  }

  /// DELETE /reviews/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/reviews/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Review not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to delete review $id (code: ${res.statusCode})",
        );
    }
  }
}
