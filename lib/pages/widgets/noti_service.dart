import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final String baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

  Future<Map<String, List<Map<String, dynamic>>>> fetchNotifications(
    int userId,
  ) async {
    try {
      final url = Uri.parse("$baseUrl/notifications");
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception("Failed to load notifications");
      }

      final List<dynamic> data = jsonDecode(response.body);
      final Map<String, List<Map<String, dynamic>>> categorized = {
        "learner": [],
        "teacher": [],
        "system": [],
      };

      for (var n in data) {
        if (n["user_id"] == userId) {
          final mapped = {
            "id": n["ID"],
            "title": n["notification_type"].toString().toUpperCase(),
            "text": n["notification_description"],
            "time": n["notification_date"],
            "isRead": n["read_flag"],
            "type": n["notification_type"],
            "userId": n["user_id"],
          };

          switch (n["notification_type"]) {
            case "learner":
              categorized["learner"]!.add(mapped);
              break;
            case "teacher":
              categorized["teacher"]!.add(mapped);
              break;
            default:
              categorized["system"]!.add(mapped);
          }
        }
      }

      return categorized;
    } catch (e) {
      throw Exception("Error fetching notifications: $e");
    }
  }

  Future<void> deleteNotification(int id) async {
    final url = Uri.parse("$baseUrl/notifications/$id");
    final response = await http.delete(
      url,
      headers: {'accept': 'application/json'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete notification $id');
    }
  }

  Future<bool> markAsRead(Map<String, dynamic> notification) async {
    final int id = notification["id"];
    final String url = "$baseUrl/notifications/$id";

    final body = {
      "notification_date": notification["time"],
      "notification_description": notification["text"],
      "notification_type": notification["type"],
      "read_flag": true,
      "user_id": notification["userId"],
    };

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          "accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print("✅ Notification $id marked as read");
        return true;
      } else {
        print(
          "❌ Failed to mark as read (${response.statusCode}): ${response.body}",
        );
        return false;
      }
    } catch (e) {
      print("⚠️ Error marking notification as read: $e");
      return false;
    }
  }
}

// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotiService{
//   final notificationsPlugin = FlutterLocalNotificationsPlugin();

//   bool _isInitialized = false;

//   bool get isInitialized => _isInitialized;

//   //initaillized
//   Future<void> initNotification() async{
//     if(_isInitialized) return; //Prevent re-initialization

//     //Prepare android init settings
//     const initSettingAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

//     // const initSettingIOS = DarwinInitializationSettings(
//     //   requestAlertPermission: true,
//     //   requestBadgePermission: true,
//     //   requestSoundPermission: true,
//     // );

//     const initSettings = InitializationSettings(
//       android: initSettingAndroid,
//       // iOS: initSettingIOS,
//     );

//     await notificationsPlugin.initialize(initSettings);
//   }
//   // Notification Detail
//   NotificationDetails notificationDetails(){
//     return const NotificationDetails(
//       android: AndroidNotificationDetails(
//         'daily_channel_id',
//         'Daily Notifications',
//         channelDescription: 'Daily Notifications Channel',
//         importance: Importance.max,
//         priority: Priority.high,
//       ),
//       // iOS: DarwinNotificationDetails(),
//     );
//   }
//   // Show Notification
//   Future<void> showNotification({
//     int id = 0,
//     String? title,
//     String? body,
//   }) async {
//     return notificationsPlugin.show(id, title, body, const NotificationDetails(),
//     );
//   }
//   //On noti tap
// }
