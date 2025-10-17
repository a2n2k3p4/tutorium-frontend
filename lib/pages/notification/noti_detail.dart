import 'package:flutter/material.dart';

class NotiDetail extends StatelessWidget {
  final Map<String, dynamic> notification;

  const NotiDetail({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    print("📄 [DETAIL] Opening notification detail");
    print("   - ID: ${notification["id"]}");
    print("   - Title: ${notification["title"]}");
    print("   - Type: ${notification["type"]}");
    print("   - Read: ${notification["isRead"]}");

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Notification Detail",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification["title"],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(notification["text"], style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text(
              "Received: ${notification["time"]}",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
