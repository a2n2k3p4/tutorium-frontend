import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/login/user_login.dart';

class LoginKuPage extends StatefulWidget {
  const LoginKuPage({super.key});

  @override
  State<LoginKuPage> createState() => _LoginKuPageState();
}

class _LoginKuPageState extends State<LoginKuPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen,
      appBar: AppBar(title: const Text(""), backgroundColor: Colors.lightGreen),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 100),
                Image.asset("assets/images/KT.png", width: 100, height: 100),
                const SizedBox(height: 215),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const UserLoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(300, 40),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        "assets/images/KU-logo.jpg",
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "KU ALL Login",
                        style: TextStyle(color: Colors.black),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.red[50],
                        title: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            const Text(
                              "Not Implemented",
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                        content: const Text(
                          "This feature is not yet implemented.",
                          style: TextStyle(color: Colors.black87),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              "Close",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    "Trouble signing in?",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
