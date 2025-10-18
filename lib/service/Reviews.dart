import 'package:tutorium_frontend/service/api_client.dart';

class Review {
  final int? id;
  final int classId;
  final int learnerId;
  final int rating;
  final String comment;

  const Review({
    this.id,
    required this.classId,
    required this.learnerId,
    required this.rating,
    required this.comment,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? json['ID'],
      classId: json['class_id'] ?? 0,
      learnerId: json['learner_id'] ?? 0,
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'class_id': classId,
      'learner_id': learnerId,
      'rating': rating,
      'comment': comment,
    };
  }

  static final ApiClient _client = ApiClient();

  /// GET /reviews (200, 500)
  static Future<List<Review>> fetchAll({Map<String, dynamic>? query}) async {
    final response = await _client.getJsonList(
      '/reviews',
      queryParameters: query,
    );
    return response.map(Review.fromJson).toList();
  }

  /// GET /reviews/:id (200, 400, 404, 500)
  static Future<Review> fetchById(int id) async {
    final response = await _client.getJsonMap('/reviews/$id');
    return Review.fromJson(response);
  }

  /// POST /reviews (201, 400, 500)
  static Future<Review> create(Review review) async {
    final response = await _client.postJsonMap(
      '/reviews',
      body: review.toJson(),
    );
    return Review.fromJson(response);
  }

  /// PUT /reviews/:id (200, 400, 404, 500)
  static Future<Review> update(int id, Review review) async {
    final response = await _client.putJsonMap(
      '/reviews/$id',
      body: review.toJson(),
    );
    return Review.fromJson(response);
  }

  /// DELETE /reviews/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    await _client.delete('/reviews/$id');
  }
}
