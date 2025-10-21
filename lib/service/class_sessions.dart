import 'package:tutorium_frontend/service/api_client.dart';

class ClassSession {
  final int id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int classId;
  final String description;
  final double price;
  final int learnerLimit;
  final String enrollmentDeadline;
  final String classStart;
  final String classFinish;
  final String classStatus;
  final String classUrl;

  ClassSession({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.classId,
    required this.description,
    required this.price,
    required this.learnerLimit,
    required this.enrollmentDeadline,
    required this.classStart,
    required this.classFinish,
    required this.classStatus,
    required this.classUrl,
  });

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      id: json["ID"] ?? 0,
      createdAt: (json['CreatedAt'] ?? '').toString(),
      updatedAt: (json['UpdatedAt'] ?? '').toString(),
      deletedAt: json['DeletedAt'],
      classId: json["class_id"],
      description: json["description"],
      price: (json["price"] as num).toDouble(),
      learnerLimit: json["learner_limit"],
      enrollmentDeadline: json['enrollment_deadline'] ?? '',
      classStart: json['class_start'] ?? '',
      classFinish: json['class_finish'] ?? '',
      classStatus: json["class_status"],
      classUrl: json["class_url"] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "class_id": classId,
      "description": description,
      "price": price,
      "learner_limit": learnerLimit,
      "enrollment_deadline": enrollmentDeadline,
      "class_start": classStart,
      "class_finish": classFinish,
      "class_status": classStatus,
      // "class_url": classUrl, // ไม่ต้องส่งตอน create
    };
  }

  ClassSession copyWith({
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    int? classId,
    String? description,
    double? price,
    int? learnerLimit,
    String? enrollmentDeadline,
    String? classStart,
    String? classFinish,
    String? classStatus,
    String? classUrl,
  }) {
    return ClassSession(
      id: id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      classId: classId ?? this.classId,
      description: description ?? this.description,
      price: price ?? this.price,
      learnerLimit: learnerLimit ?? this.learnerLimit,
      enrollmentDeadline: enrollmentDeadline ?? this.enrollmentDeadline,
      classStart: classStart ?? this.classStart,
      classFinish: classFinish ?? this.classFinish,
      classStatus: classStatus ?? this.classStatus,
      classUrl: classUrl ?? this.classUrl,
    );
  }

  static final ApiClient _client = ApiClient();

  // ---------- CRUD ----------

  /// GET /class_sessions (200)
  static Future<List<ClassSession>> fetchAll({
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.getJsonList(
      '/class_sessions',
      queryParameters: query,
    );
    return response.map(ClassSession.fromJson).toList();
  }

  /// GET /class_sessions/:id (200, 400, 404, 500)
  static Future<ClassSession> fetchById(int id) async {
    final response = await _client.getJsonMap('/class_sessions/$id');
    return ClassSession.fromJson(response);
  }

  /// POST /class_sessions (201, 400, 500)
  static Future<ClassSession> create(ClassSession session) async {
    final response = await _client.postJsonMap(
      '/class_sessions',
      body: session.toJson(),
    );
    return ClassSession.fromJson(response);
  }

  /// PUT /class_sessions/:id (200, 400, 404, 500)
  static Future<ClassSession> update(int id, ClassSession session) async {
    final response = await _client.putJsonMap(
      '/class_sessions/$id',
      body: session.toJson(),
    );
    return ClassSession.fromJson(response);
  }

  /// DELETE /class_sessions/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    try {
      await _client.delete('/class_sessions/$id');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw ApiException(404, 'Session not found');
      } else if (e.statusCode == 400) {
        throw ApiException(400, e.body ?? 'Invalid session ID');
      } else if (e.statusCode == 500) {
        throw ApiException(500, 'Failed to delete session. Please try again.');
      }
      rethrow;
    } catch (e) {
      throw Exception('Failed to delete session: ${e.toString()}');
    }
  }
}
