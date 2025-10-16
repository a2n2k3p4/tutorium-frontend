import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class Review {
  final int id;
  final int classId;
  final int? learnerUserId;
  final double? rating;
  final String? comment;

  Review({
    required this.id,
    required this.classId,
    this.learnerUserId,
    this.rating,
    this.comment,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['ID'],
      classId: json['class_id'],
      learnerUserId: json['learner_user_id'],
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : null,
      comment: json['comment'],
    );
  }
}

class User {
  final int id;
  final String? firstName;
  final String? lastName;

  User({required this.id, this.firstName, this.lastName});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['ID'],
      firstName: json['first_name'],
      lastName: json['last_name'],
    );
  }
}

class ReviewService {
  final String baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

  Future<List<Review>> getReviewsForClass(int classId) async {
    try {
      final url = Uri.parse("$baseUrl/reviews");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        final allReviews = data.map((e) => Review.fromJson(e)).toList();
        return allReviews.where((r) => r.classId == classId).toList();
      }
      return [];
    } catch (e) {
      print("Error loading reviews: $e");
      return [];
    }
  }

  Future<Map<int, User>> getAllUsersMap() async {
    try {
      final url = Uri.parse("$baseUrl/users");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        final users = data.map((u) => User.fromJson(u)).toList();
        return {for (var u in users) u.id: u};
      }
      return {};
    } catch (e) {
      print("Error loading users: $e");
      return {};
    }
  }
}
