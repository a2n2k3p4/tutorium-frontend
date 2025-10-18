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
      id: json['ID'] ?? json['id'],
      userId: json['user_id'] ?? 0,
      email: json['email'] ?? '',
      description: json['description'] ?? '',
      flagCount: json['flag_count'] ?? 0,
    );
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
}
