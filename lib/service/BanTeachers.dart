import 'package:tutorium_frontend/service/api_client.dart';

class BanTeacher {
  final int? id;
  final String banDescription;
  final String banEnd;
  final String banStart;
  final int teacherId;

  const BanTeacher({
    this.id,
    required this.banDescription,
    required this.banEnd,
    required this.banStart,
    required this.teacherId,
  });

  factory BanTeacher.fromJson(Map<String, dynamic> json) {
    return BanTeacher(
      id: json['ID'] ?? json['id'],
      banDescription: json['ban_description'] ?? '',
      banEnd: json['ban_end'] ?? '',
      banStart: json['ban_start'] ?? '',
      teacherId: json['teacher_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ban_description': banDescription,
      'ban_end': banEnd,
      'ban_start': banStart,
      'teacher_id': teacherId,
    };
  }

  static final ApiClient _client = ApiClient();

  static Future<List<BanTeacher>> fetchAll({
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.getJsonList(
      '/banteachers',
      queryParameters: query,
    );
    return response.map(BanTeacher.fromJson).toList();
  }

  static Future<BanTeacher> fetchById(int id) async {
    final response = await _client.getJsonMap('/banteachers/$id');
    return BanTeacher.fromJson(response);
  }

  static Future<BanTeacher> create(BanTeacher ban) async {
    final response = await _client.postJsonMap(
      '/banteachers',
      body: ban.toJson(),
    );
    return BanTeacher.fromJson(response);
  }

  static Future<BanTeacher> update(int id, BanTeacher ban) async {
    final response = await _client.putJsonMap(
      '/banteachers/$id',
      body: ban.toJson(),
    );
    return BanTeacher.fromJson(response);
  }

  static Future<void> delete(int id) async {
    await _client.delete('/banteachers/$id');
  }
}
