import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:tutorium_frontend/pages/login/login_ku.dart';
// import 'package:tutorium_frontend/pages/main_nav_page.dart';
// import 'package:tutorium_frontend/pages/widgets/noti_service.dart';

// FOR TESTING: Import Learn Page
import 'package:tutorium_frontend/pages/learn/learn.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // NotiService().initNotification();
  await dotenv.load(fileName: ".env");

  // Setup test user data for Jitsi
  await _setupTestUserData();

  runApp(const MyApp());
}

// Setup mock user data for testing
Future<void> _setupTestUserData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('userName', 'Test Student');
  await prefs.setString('userEmail', 'test.student@ku.th');
  await prefs.setInt('userId', 12345);
  await prefs.setBool('isTeacher', false);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final mockup_link = dotenv.env["JITSI_URL"]! + "/test";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KU Tutorium - Jitsi Test',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      // FOR TESTING: Direct to Learn Page with mock data
      home: LearnPage(
        classSessionId: 999,
        className: 'Test Class - Introduction to Flutter',
        teacherName: 'Prof. Test Teacher',
        isTeacher: false,
        jitsiMeetingUrl: mockup_link, // Set to true to test teacher mode
      ),
      // PRODUCTION: Use LoginKuPage or MainNavPage
      // home: LoginKuPage(),
    );
  }
}
