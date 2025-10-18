import 'package:flutter/material.dart';

class TeacherHomePage extends StatelessWidget {
  final VoidCallback onSwitch;

  const TeacherHomePage({super.key, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                child: const Text(
                  "Teacher Home",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 28.0,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.co_present,
                        color: Colors.green,
                        size: 32,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.change_circle,
                        color: Colors.green,
                        size: 32,
                      ),
                      onPressed: onSwitch,
                      tooltip: 'Switch to Learner Mode',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text(
          "Teacher Home - Coming Soon",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
