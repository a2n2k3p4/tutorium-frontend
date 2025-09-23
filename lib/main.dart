import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tutorium_frontend/pages/login/login_ku.dart';
// import 'package:tutorium_frontend/pages/widgets/noti_service.dart';

void main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // NotiService().initNotification();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KU Tutorium',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      // home: MainNavPage(),
      home: LoginKuPage(),
    );
  }
}
