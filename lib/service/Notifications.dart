import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class NotificationModel {
  final String notificationDate;
  final String notificationDescription;
  final String notificationType;
  final bool readFlag;
  final int userId;

  NotificationModel({
    required this.notificationDate,
    required this.notificationDescription,
    required this.notificationType,
    required this.readFlag,
    required this.userId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationDate: json['notification_date'],
      notificationDescription: json['notification_description'],
      notificationType: json['notification_type'],
      readFlag: json['read_flag'],
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_date': notificationDate,
      'notification_description': notificationDescription,
      'notification_type': notificationType,
      'read_flag': readFlag,
      'user_id': userId,
    };
  }

  // ---------- CRUD ----------

  /// GET /notifications (200, 500)
  static Future<List<NotificationModel>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/notifications"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => NotificationModel.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch notifications (code: ${res.statusCode})",
        );
    }
  }

  /// GET /notifications/:id (200, 400, 404, 500)
  static Future<NotificationModel> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/notifications/$id"));
    switch (res.statusCode) {
      case 200:
        return NotificationModel.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Notification not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch notification $id (code: ${res.statusCode})",
        );
    }
  }

  /// POST /notifications (201, 400, 500)
  static Future<NotificationModel> create(
    NotificationModel notification,
  ) async {
    final res = await http.post(
      ApiService.endpoint("/notifications"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(notification.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return NotificationModel.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to create notification (code: ${res.statusCode})",
        );
    }
  }

  /// PUT /notifications/:id (200, 400, 404, 500)
  static Future update(int id, NotificationModel notification) async {
    final res = await http.put(
      ApiService.endpoint("/notifications/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(notification.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return NotificationModel.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("Notification not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to update notification $id (code: ${res.statusCode})",
        );
    }
  }

  /// DELETE /notifications/:id (200, 400, 404, 500)
  static Future delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/notifications/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Notification not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to delete notification $id (code: ${res.statusCode})",
        );
    }
  }
}
