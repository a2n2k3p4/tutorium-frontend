import 'package:flutter/material.dart';
import 'pages/main_nav_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KU Tutorium',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const MainNavPage(),
    );
  }
}
