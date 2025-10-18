import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

  Future<List<dynamic>> getAllClasses() async {
    final url = Uri.parse("$baseUrl/classes");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load classes");
    }
  }

  Future<List<dynamic>> searchClass(String query) async {
    final queryParams = {"class_description": query, "class_name": query};

    final url = Uri.parse(
      "$baseUrl/classes",
    ).replace(queryParameters: queryParams);

    print("Search request: $url");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to search classes");
    }
  }

  Future<List<dynamic>> filterClasses({
    List<String>? categories,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    double? maxRating,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (categories != null && categories.isNotEmpty) {
      queryParams["category"] = categories.join(",");
    }

    if (minPrice != null) queryParams["min_price"] = minPrice.toString();
    if (maxPrice != null) queryParams["max_price"] = maxPrice.toString();
    if (minRating != null) queryParams["min_rating"] = minRating.toString();
    if (maxRating != null) queryParams["max_rating"] = maxRating.toString();
    if (search != null && search.isNotEmpty) queryParams["search"] = search;

    final uri = Uri.parse(
      "$baseUrl/classes",
    ).replace(queryParameters: queryParams);

    print("Filter request: $uri");

    final response = await http.get(uri);
    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      print("Filter success — found ${result.length} classes");
      return result;
    } else {
      print("Filter failed: ${response.statusCode}");
      throw Exception("Failed to filter classes (${response.statusCode})");
    }
  }

  // Notification APIs
  Future<List<dynamic>> getAllNotifications() async {
    final url = Uri.parse("$baseUrl/notifications");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load notifications");
    }
  }

  Future<Map<String, dynamic>> getNotificationById(int id) async {
    final url = Uri.parse("$baseUrl/notifications/$id");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load notification");
    }
  }

  Future<Map<String, dynamic>> createNotification({
    required int userId,
    required String notificationType,
    required String notificationDescription,
    DateTime? notificationDate,
    bool readFlag = false,
  }) async {
    final url = Uri.parse("$baseUrl/notifications");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "user_id": userId,
        "notification_type": notificationType,
        "notification_description": notificationDescription,
        "notification_date": (notificationDate ?? DateTime.now())
            .toIso8601String(),
        "read_flag": readFlag,
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to create notification");
    }
  }

  Future<Map<String, dynamic>> updateNotification({
    required int id,
    int? userId,
    String? notificationType,
    String? notificationDescription,
    DateTime? notificationDate,
    bool? readFlag,
  }) async {
    final url = Uri.parse("$baseUrl/notifications/$id");
    final body = <String, dynamic>{};

    if (userId != null) body["user_id"] = userId;
    if (notificationType != null) body["notification_type"] = notificationType;
    if (notificationDescription != null) {
      body["notification_description"] = notificationDescription;
    }
    if (notificationDate != null) {
      body["notification_date"] = notificationDate.toIso8601String();
    }
    if (readFlag != null) body["read_flag"] = readFlag;

    final response = await http.put(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to update notification");
    }
  }

  Future<void> deleteNotification(int id) async {
    final url = Uri.parse("$baseUrl/notifications/$id");
    final response = await http.delete(url);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception("Failed to delete notification");
    }
  }

  Future<void> markNotificationAsRead(int id) async {
    await updateNotification(id: id, readFlag: true);
  }

  Future<List<dynamic>> getUnreadNotifications() async {
    final notifications = await getAllNotifications();
    return notifications.where((n) => n['read_flag'] == false).toList();
  }
}
