import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/home/teacher/register/teacher_register.dart';

class BecomeTeacherHomePage extends StatefulWidget {
  final VoidCallback onSwitch;
  const BecomeTeacherHomePage({super.key, required this.onSwitch});

  @override
  State<BecomeTeacherHomePage> createState() => _BecomeTeacherHomePageState();
}

class _BecomeTeacherHomePageState extends State<BecomeTeacherHomePage> {
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
                    Icons.co_present,
                    color: Colors.green,
                    size: 40,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.change_circle,
                      color: Colors.green,
                      size: 50,
                    ),
                    onPressed: widget.onSwitch,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 200),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(40),
                side: const BorderSide(color: Colors.black, width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const TeacherRegisterPage()),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.co_present_rounded,
                    size: 60,
                    color: Colors.black,
                  ),
                  SizedBox(height: 15),
                  Text(
                    "Become a Teacher",
                    style: TextStyle(
                      fontSize: 23,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
