import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/home/teacher/register/teacher_register.dart';
import 'package:tutorium_frontend/service/teacher_registration_service.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

class BecomeTeacherHomePage extends StatefulWidget {
  final VoidCallback onSwitch;
  const BecomeTeacherHomePage({super.key, required this.onSwitch});

  @override
  State<BecomeTeacherHomePage> createState() => _BecomeTeacherHomePageState();
}

class _BecomeTeacherHomePageState extends State<BecomeTeacherHomePage> {
  bool _isChecking = false;

  Future<void> _handleBecomeTeacher() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final userId = await LocalStorage.getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      debugPrint("DEBUG BecomeTeacher: Checking eligibility for user $userId");

      // ตรวจสอบว่าเป็น Teacher อยู่แล้วหรือไม่
      final eligibility =
          await TeacherRegistrationService.checkTeacherEligibility(userId);

      if (!mounted) return;

      setState(() {
        _isChecking = false;
      });

      if (eligibility.isAlreadyTeacher) {
        // ถ้าเป็น Teacher อยู่แล้ว ให้แจ้งเตือนและ switch
        debugPrint("DEBUG BecomeTeacher: User is already a teacher");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are already a teacher! Switching to Teacher Home...',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // รอ 1 วินาที แล้วค่อย switch
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          widget.onSwitch();
        }
      } else {
        // ถ้ายังไม่ได้เป็น Teacher ให้ไปหน้าสมัคร
        debugPrint(
          "DEBUG BecomeTeacher: Not a teacher yet, navigating to registration",
        );

        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => const TeacherRegisterPage()),
        );

        // ถ้าสมัครสำเร็จ ให้ switch ไป Teacher Home
        if (result == true && mounted) {
          widget.onSwitch();
        }
      }
    } catch (e) {
      debugPrint("ERROR BecomeTeacher: Failed to check eligibility: $e");

      if (!mounted) return;

      setState(() {
        _isChecking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
                  const Icon(Icons.co_present, color: Colors.green, size: 40),
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
            child: _isChecking
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Checking your teacher status...'),
                    ],
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(40),
                      side: const BorderSide(color: Colors.black, width: 1.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: _handleBecomeTeacher,
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
                          style: TextStyle(fontSize: 23, color: Colors.black),
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
