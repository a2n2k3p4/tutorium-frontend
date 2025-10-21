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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600;

    return Scaffold(
      backgroundColor: Colors.lightGreen,
      appBar: AppBar(title: const Text(""), backgroundColor: Colors.lightGreen),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.08,
              vertical: 20,
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      screenHeight -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: isSmallScreen ? 40 : screenHeight * 0.15),
                    Image.asset(
                      "assets/images/KT.png",
                      width: isSmallScreen ? 80 : screenWidth * 0.25,
                      height: isSmallScreen ? 80 : screenWidth * 0.25,
                    ),
                    SizedBox(height: isSmallScreen ? 60 : screenHeight * 0.25),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => const UserLoginPage(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                const Flexible(
                                  child: Text(
                                    "Not Implemented",
                                    style: TextStyle(color: Colors.red),
                                  ),
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
                    SizedBox(height: isSmallScreen ? 20 : 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
