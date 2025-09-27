import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/home/teacher/register/payment_screen.dart';

class TeacherRegisterPage extends StatefulWidget {
  const TeacherRegisterPage({super.key});

  @override
  State<TeacherRegisterPage> createState() => _TeacherRegisterPage();
}

class _TeacherRegisterPage extends State<TeacherRegisterPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.lightGreen),
      backgroundColor: Colors.lightGreen,
      body: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Teacher Register", style: TextStyle(fontSize: 40)),
            const SizedBox(height: 20),
            Text(
              "To be come a teacher, You need to pay a one-time registration fee of 200 THB. This fee ensures teacher verification and helps us maintain a safe platform for all Learners.",
              style: TextStyle(
                fontSize: 20,
                color: const Color.fromARGB(255, 83, 82, 82),
              ),
            ),
            const SizedBox(height: 35),
            Padding(
              padding: const EdgeInsets.only(left: 115),
              child: Image.asset(
                "assets/images/Teacher.png",
                width: 120,
                height: 120,
              ),
            ),
            const SizedBox(height: 35),
            Text("What you will get", style: TextStyle(fontSize: 25)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 25),
                  SizedBox(width: 5),
                  Text(
                    "Create your own classes",
                    style: TextStyle(fontSize: 23),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Row(
                children: [
                  Image.asset(
                    "assets/images/MoneyBagIcon.png",
                    width: 25,
                    height: 25,
                    color: Colors.black,
                  ),
                  SizedBox(width: 5),
                  Text(
                    "Earn income from teaching",
                    style: TextStyle(fontSize: 23),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Row(
                children: [
                  Image.asset(
                    "assets/images/DashboardIcon.png",
                    width: 25,
                    height: 25,
                    color: Colors.black,
                  ),
                  SizedBox(width: 5),
                  Text(
                    "Teacher dashboard access",
                    style: TextStyle(fontSize: 23),
                  ),
                ],
              ),
            ),
            SizedBox(height: 110),
            Padding(
              padding: const EdgeInsets.only(left: 80),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => const PaymentScreen(userId: 1),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.fromLTRB(40, 10, 40, 10),
                  backgroundColor: Colors.lightGreenAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(
                      color: Color.fromARGB(255, 0, 0, 0),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Text(
                  "Pay 200 THB",
                  style: TextStyle(
                    color: const Color.fromARGB(255, 28, 83, 29),
                    fontSize: 23,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
