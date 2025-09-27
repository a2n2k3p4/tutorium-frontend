import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/pages/main_nav_page.dart';

class User {
  final int id;
  final String? studentId;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? phoneNumber;
  final int balance;
  final int banCount;

  User({
    required this.id,
    this.studentId,
    this.firstName,
    this.lastName,
    this.gender,
    this.phoneNumber,
    required this.balance,
    required this.banCount,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['ID'],
      studentId: json['student_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      gender: json['gender'],
      phoneNumber: json['phone_number'],
      balance: json['balance'] ?? 0,
      banCount: json['ban_count'] ?? 0,
    );
  }
}

class LoginResponse {
  final String token;
  final User user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'],
      user: User.fromJson(json['user']),
    );
  }
}

// API function
Future<LoginResponse> fetchUser(String username, String password) async {
  try {
    final loginData = {'username': username, 'password': password};
    final apiKey = dotenv.env["LOGIN_API"];
    final response = await http.post(
      Uri.parse('$apiKey'),
      headers: {
        'User-Agent': 'flutter_app',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(loginData),
    );

    print('Status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonMap = jsonDecode(response.body);
      return LoginResponse.fromJson(jsonMap);
    } else {
      throw Exception('Failed to login (status code ${response.statusCode})');
    }
  } catch (e) {
    print('Exception caught: $e');
    rethrow;
  }
}

// UI: Login Page
class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text;
      final password = _passwordController.text;

      try {
        // final loginResponse = await fetchUser(username, password);
        final _ = await fetchUser(username, password);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainNavPage()),
          (route) => false,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login successfully')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.lightGreen,
      appBar: AppBar(title: const Text(""), backgroundColor: Colors.lightGreen),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Login", style: TextStyle(fontSize: 30)),
              const SizedBox(height: 50),

              // Username field
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: "Username",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Enter username" : null,
              ),
              const SizedBox(height: 40),

              // Password field
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "Password",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                obscureText: true,
                validator: (value) =>
                    value == null || value.isEmpty ? "Enter password" : null,
              ),
              const SizedBox(height: 40),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("Next"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
