import 'package:tutorium_frontend/service/api_client.dart';

class Teacher {
  final int? id;
  final int userId;
  final String email;
  final String description;
  final int flagCount;

  const Teacher({
    this.id,
    required this.userId,
    required this.email,
    required this.description,
    required this.flagCount,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: _parseInt(json['ID'] ?? json['id']),
      userId: _parseInt(json['user_id']) ?? 0,
      email: json['email']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      flagCount: _parseInt(json['flag_count']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'email': email,
      'description': description,
      'flag_count': flagCount,
    };
  }

  static final ApiClient _client = ApiClient();

  static Future<List<Teacher>> fetchAll({Map<String, dynamic>? query}) async {
    final response = await _client.getJsonList(
      '/teachers',
      queryParameters: query,
    );
    return response.map(Teacher.fromJson).toList();
  }

  static Future<Teacher> fetchById(int id) async {
    final response = await _client.getJsonMap('/teachers/$id');
    return Teacher.fromJson(response);
  }

  static Future<Teacher> create(Teacher teacher) async {
    final response = await _client.postJsonMap(
      '/teachers',
      body: teacher.toJson(),
    );
    return Teacher.fromJson(response);
  }

  static Future<Teacher> update(int id, Teacher teacher) async {
    final response = await _client.putJsonMap(
      '/teachers/$id',
      body: teacher.toJson(),
    );
    return Teacher.fromJson(response);
  }

  static Future<void> delete(int id) async {
    await _client.delete('/teachers/$id');
  }

  static Future<double?> fetchAverageRating(int teacherId) async {
    try {
      final response = await _client.getJsonMap(
        '/teachers/$teacherId/average_rating',
      );
      return _parseDouble(response['average_rating']);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
