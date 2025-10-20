import 'package:tutorium_frontend/service/api_client.dart';

class Admin {
  final int id;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int userId;

  const Admin({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.userId,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['ID'] ?? json['id'] ?? 0,
      createdAt: json['CreatedAt'] ?? '',
      updatedAt: json['UpdatedAt'] ?? '',
      deletedAt: json['DeletedAt'],
      userId: json['user_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'user_id': userId};

  static final ApiClient _client = ApiClient();

  static Future<List<Admin>> fetchAll() async {
    final response = await _client.getJsonList('/admins');
    return response.map(Admin.fromJson).toList();
  }

  static Future<Admin> fetchById(int id) async {
    final response = await _client.getJsonMap('/admins/$id');
    return Admin.fromJson(response);
  }

  static Future<Admin> create(int userId) async {
    final response = await _client.postJsonMap(
      '/admins',
      body: {'user_id': userId},
    );
    return Admin.fromJson(response);
  }

  static Future<void> delete(int id) async {
    await _client.delete('/admins/$id');
  }
}
