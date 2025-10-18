import 'package:tutorium_frontend/service/api_client.dart';

class NotificationModel {
  final int? id;
  final DateTime notificationDate;
  final String notificationDescription;
  final String notificationType;
  final bool readFlag;
  final int userId;

  NotificationModel({
    this.id,
    required this.notificationDate,
    required this.notificationDescription,
    required this.notificationType,
    required this.readFlag,
    required this.userId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? json['ID'],
      notificationDate: DateTime.parse(json['notification_date']).toUtc(),
      notificationDescription: json['notification_description'] ?? '',
      notificationType: json['notification_type'] ?? 'system',
      readFlag: json['read_flag'] ?? false,
      userId: json['user_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'notification_date': notificationDate.toIso8601String(),
      'notification_description': notificationDescription,
      'notification_type': notificationType,
      'read_flag': readFlag,
      'user_id': userId,
    };
  }

  static final ApiClient _client = ApiClient();

  /// GET /notifications (200, 500)
  static Future<List<NotificationModel>> fetchAll({
    Map<String, dynamic>? query,
  }) async {
    final response = await _client.getJsonList(
      '/notifications',
      queryParameters: query,
    );
    return response.map(NotificationModel.fromJson).toList();
  }

  /// GET /notifications/:id (200, 400, 404, 500)
  static Future<NotificationModel> fetchById(int id) async {
    final response = await _client.getJsonMap('/notifications/$id');
    return NotificationModel.fromJson(response);
  }

  /// POST /notifications (201, 400, 500)
  static Future<NotificationModel> create(
    NotificationModel notification,
  ) async {
    final response = await _client.postJsonMap(
      '/notifications',
      body: notification.toJson(),
    );
    return NotificationModel.fromJson(response);
  }

  /// PUT /notifications/:id (200, 400, 404, 500)
  static Future<NotificationModel> update(
    int id,
    NotificationModel notification,
  ) async {
    final response = await _client.putJsonMap(
      '/notifications/$id',
      body: notification.toJson(),
    );
    return NotificationModel.fromJson(response);
  }

  /// DELETE /notifications/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    await _client.delete('/notifications/$id');
  }
}
