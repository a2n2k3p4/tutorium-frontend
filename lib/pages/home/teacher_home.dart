import 'package:flutter/material.dart';

class TeacherHomePage extends StatelessWidget {
  final VoidCallback onSwitch;
  const TeacherHomePage({super.key, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: const Text(
                "Teacher Home",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 36.0,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Row(
                children: [
                  const Icon(
                    Icons.co_present, // ← ใช้เป็นสัญลักษณ์ธรรมดา
                    color: Colors.green,
                    size: 40,
                  ),
                  const SizedBox(width: 8), // ระยะห่างระหว่าง icons
                  IconButton(
                    icon: const Icon(
                      Icons.change_circle,
                      color: Colors.green,
                      size: 50,
                    ),
                    onPressed: onSwitch,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(child: const Text("Nothing")),
    );
  }
}
