import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/login/login_ku.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<StatefulWidget> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 175),
              Image.asset("assets/images/KT.png", width: 100, height: 100),
              const SizedBox(height: 215),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => LoginKuPage()),
                  );
                },
                style: ElevatedButton.styleFrom(fixedSize: Size(300, 40)),
                child: Text(
                  "User Login",
                  style: TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(fixedSize: Size(300, 40)),
                child: Text(
                  "Admin Login",
                  style: TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {},
                child: Text(
                  "Trouble signing in?",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
