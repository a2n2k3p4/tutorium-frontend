import 'package:tutorium_frontend/service/api_client.dart';

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

  static final ApiClient _client = ApiClient();

  /// GET /enrollments (200, 500)
  static Future<List<Enrollment>> fetchAll({
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.getJsonList(
      '/enrollments',
      queryParameters: query,
    );
    return response.map(Enrollment.fromJson).toList();
  }

  /// GET /enrollments/:id (200, 400, 404, 500)
  static Future<Enrollment> fetchById(int id) async {
    final response = await _client.getJsonMap('/enrollments/$id');
    return Enrollment.fromJson(response);
  }

  /// POST /enrollments (201, 400, 500)
  static Future<Enrollment> create(Enrollment enrollment) async {
    final response = await _client.postJsonMap(
      '/enrollments',
      body: enrollment.toJson(),
    );
    return Enrollment.fromJson(response);
  }

  /// PUT /enrollments/:id (200, 400, 404, 500)
  static Future<Enrollment> update(int id, Enrollment enrollment) async {
    final response = await _client.putJsonMap(
      '/enrollments/$id',
      body: enrollment.toJson(),
    );
    return Enrollment.fromJson(response);
  }

  /// DELETE /enrollments/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    await _client.delete('/enrollments/$id');
  }
}
