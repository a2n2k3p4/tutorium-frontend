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