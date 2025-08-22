import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text("Notification"),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 36.0,
          fontWeight: FontWeight.normal,
        ),
      ),
      body: Center(child: Text("Notification Page")),
    );
  }
}
