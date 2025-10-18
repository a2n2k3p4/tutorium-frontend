import 'package:tutorium_frontend/service/api_client.dart';

class Learner {
  final int? id;
  final int flagCount;
  final int userId;

  const Learner({this.id, required this.flagCount, required this.userId});

  factory Learner.fromJson(Map<String, dynamic> json) {
    return Learner(
      id: json['ID'] ?? json['id'],
      flagCount: json['flag_count'] ?? 0,
      userId: json['user_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'flag_count': flagCount,
      'user_id': userId,
    };
  }

  static final ApiClient _client = ApiClient();

  static Future<List<Learner>> fetchAll({Map<String, dynamic>? query}) async {
    final response = await _client.getJsonList(
      '/learners',
      queryParameters: query,
    );
    return response.map(Learner.fromJson).toList();
  }

  static Future<Learner> fetchById(int id) async {
    final response = await _client.getJsonMap('/learners/$id');
    return Learner.fromJson(response);
  }

  static Future<Learner> create(Learner learner) async {
    final response = await _client.postJsonMap(
      '/learners',
      body: learner.toJson(),
    );
    return Learner.fromJson(response);
  }

  static Future<void> delete(int id) async {
    await _client.delete('/learners/$id');
  }
}
