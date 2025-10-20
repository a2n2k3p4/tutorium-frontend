import 'package:tutorium_frontend/service/api_client.dart';

class BanLearner {
  final int? id;
  final String banDescription;
  final String banEnd;
  final String banStart;
  final int learnerId;

  const BanLearner({
    this.id,
    required this.banDescription,
    required this.banEnd,
    required this.banStart,
    required this.learnerId,
  });

  factory BanLearner.fromJson(Map<String, dynamic> json) {
    return BanLearner(
      id: json['ID'] ?? json['id'],
      banDescription: json['ban_description'] ?? '',
      banEnd: json['ban_end'] ?? '',
      banStart: json['ban_start'] ?? '',
      learnerId: json['learner_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ban_description': banDescription,
      'ban_end': banEnd,
      'ban_start': banStart,
      'learner_id': learnerId,
    };
  }

  static final ApiClient _client = ApiClient();

  static Future<List<BanLearner>> fetchAll({
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.getJsonList(
      '/banlearners',
      queryParameters: query,
    );
    return response.map(BanLearner.fromJson).toList();
  }

  static Future<BanLearner> fetchById(int id) async {
    final response = await _client.getJsonMap('/banlearners/$id');
    return BanLearner.fromJson(response);
  }

  static Future<BanLearner> create(BanLearner ban) async {
    final response = await _client.postJsonMap(
      '/banlearners',
      body: ban.toJson(),
    );
    return BanLearner.fromJson(response);
  }

  static Future<BanLearner> update(int id, BanLearner ban) async {
    final response = await _client.putJsonMap(
      '/banlearners/$id',
      body: ban.toJson(),
    );
    return BanLearner.fromJson(response);
  }

  static Future<void> delete(int id) async {
    await _client.delete('/banlearners/$id');
  }
}
