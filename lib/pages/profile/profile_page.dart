import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? user;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    try {
      // make sure API_URL is defined in your .env file
      final apiKey = dotenv.env["API_URL"];
      final port = dotenv.env["PORT"];

      final apiUrl = "${apiKey}:${port}/users/6"; // Example endpoint
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          user = User.fromJson(jsonData);
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load user");
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: const Text("Your Profile"),
            ),
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.grey,
                    size: 25,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isLoading ? "..." : (user?.balance.toString() ?? "0.0"),
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.add_circle_rounded,
                    color: Colors.grey,
                    size: 25,
                  ),
                ],
              ),
            ),
          ],
        ),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 36.0,
          fontWeight: FontWeight.normal,
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 15),

              // Profile Icon
              const Icon(
                Icons.account_circle_rounded,
                color: Colors.black,
                size: 100,
              ),

              const SizedBox(width: 20),

              // Name + Gender + Extra Text
              if (!isLoading)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "${user?.firstName ?? ''} ${user?.lastName ?? ''}",
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          user?.gender?.toLowerCase() == "male"
                              ? Icons.male
                              : user?.gender?.toLowerCase() == "female"
                              ? Icons.female
                              : Icons.account_circle_rounded,
                          color: user?.gender?.toLowerCase() == "male"
                              ? Colors.blue
                              : user?.gender?.toLowerCase() == "female"
                              ? Colors.red
                              : Colors.black,
                          size: 30,
                        ),
                      ],
                    ),

                    // const SizedBox(height: 1),
                    Text(
                      "Email",
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    Text(
                      "Learner & Teacher",
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    Row(
                      children: [
                        Text(
                          "Teacher rate : 4.0",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Icon(
                          Icons.star,
                          color: const Color.fromARGB(255, 250, 225, 0),
                        ),
                      ],
                    ),
                  ],
                )
              else
                const Text("Loading..."),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(right: 250),
            child: Text(
              "Description",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 110),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 170),
                child: Text(
                  "   Classes",
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black, 
                  padding: EdgeInsets.zero,
                ),
                child: const Text("   See more",style: TextStyle( color: Colors.grey),),
              ),
              Icon(
                Icons.keyboard_arrow_right,
                color: Colors.black,
              )
            ],
          ),
        ],
      ),
    );
  }
}
