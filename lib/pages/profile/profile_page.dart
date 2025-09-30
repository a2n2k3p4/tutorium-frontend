import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:tutorium_frontend/pages/profile/allClasses_page.dart';
import 'package:tutorium_frontend/pages/widgets/history_class.dart';

class User {
  final int id;
  final String? studentId;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? phoneNumber;
  final double balance;
  final int banCount;
  final String? profilePicture;
  final Teacher? teacher;
  final Learner? learner;

  User({
    required this.id,
    this.studentId,
    this.firstName,
    this.lastName,
    this.gender,
    this.phoneNumber,
    required this.balance,
    required this.banCount,
    this.profilePicture,
    this.teacher,
    this.learner,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['ID'],
      studentId: json['student_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      gender: json['gender'],
      phoneNumber: json['phone_number'],
      balance: (json['balance'] ?? 0).toDouble(),
      banCount: json['ban_count'] ?? 0,
      profilePicture: json['profile_picture'],
      teacher: json['Teacher'] != null
          ? Teacher.fromJson(json['Teacher'])
          : null,
      learner: json['Learner'] != null
          ? Learner.fromJson(json['Learner'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "ID": id,
      "student_id": studentId,
      "first_name": firstName,
      "last_name": lastName,
      "gender": gender,
      "phone_number": phoneNumber,
      "balance": balance,
      "ban_count": banCount,
      "profile_picture": profilePicture,
      "Teacher": teacher,
      "Learner": learner,
    };
  }
}

class Teacher {
  final int id;
  final int userId;
  final String? description;
  final int? flagCount;
  final String? email;

  Teacher({
    required this.id,
    required this.userId,
    this.description,
    this.flagCount,
    this.email,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['ID'],
      userId: json['user_id'],
      description: json['description'] ?? '',
      flagCount: json['flag_count'] ?? 0,
      email: json['email'] ?? '',
    );
  }
}

class Learner {
  final int id;
  final int userId;
  final int? flagCount;

  Learner({required this.id, required this.userId, this.flagCount});

  factory Learner.fromJson(Map<String, dynamic> json) {
    return Learner(
      id: json['ID'],
      userId: json['user_id'],
      flagCount: json['flag_count'] ?? 0,
    );
  }
}

class Class {
  final int id;
  final String className;
  final double? rating;
  final String teacherName;

  Class({
    required this.id,
    required this.className,
    this.rating,
    required this.teacherName,
  });

  factory Class.fromJson(Map<String, dynamic> json) {
    return Class(
      id: json['id'],
      className: json['class_name'],
      rating: (json['rating'] ?? 0).toDouble(),
      teacherName: json['teacher_name'],
    );
  }
}

class Review {
  final int id;
  final int learnerId;
  final int classId;
  final String? comment;
  final double? rating;
  final int? learnerUserId;

  Review({
    required this.id,
    required this.learnerId,
    required this.classId,
    this.comment,
    this.rating,
    this.learnerUserId,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['ID'],
      learnerId: json['learner_id'],
      classId: json['class_id'],
      comment: json['comment'],
      rating: (json['rating'] ?? 0).toDouble(),
      learnerUserId: json['Learner']?['user_id'],
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
  List<Class> allClasses = [];
  List<Class> myClasses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    try {
      final apiKey = dotenv.env["API_URL"];
      final port = dotenv.env["PORT"];

      final apiUrl = "$apiKey:$port/users/3"; //Put the real user id here
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          user = User.fromJson(jsonData);
          isLoading = false;
        });
        await fetchClasses();
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

  Future<void> fetchClasses() async {
    try {
      final apiKey = dotenv.env["API_URL"];
      final port = dotenv.env["PORT"];

      final apiUrl = "$apiKey:$port/classes";
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        final fetchedClasses = jsonData.map((c) => Class.fromJson(c)).toList();

        setState(() {
          allClasses = fetchedClasses;

          if (user?.teacher != null) {
            final fullName = "${user?.firstName ?? ''} ${user?.lastName ?? ''}"
                .trim();
            myClasses = allClasses
                .where((c) => c.teacherName == fullName)
                .toList();
          }
        });
      } else {
        throw Exception("Failed to load classes");
      }
    } catch (e) {
      print("Error fetching classes: $e");
    }
  }

  Future<String?> pickImageAndConvertToBase64() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      return base64Encode(bytes);
    }
    return null;
  }

  Future<void> uploadProfilePicture(int userId, String base64Image) async {
    final apiKey = dotenv.env["API_URL"];
    final port = dotenv.env["PORT"];
    final apiUrl = "$apiKey:$port/users/3"; //Put the real user id here

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"user_id": userId, "profile_picture": base64Image}),
    );

    if (response.statusCode == 200) {
      print("Upload success");
    } else {
      print("Upload failed: ${response.body}");
    }
  }

  ImageProvider? _getImageProvider(String? value) {
    if (value == null || value.isEmpty) return null;

    if (value.startsWith("http")) {
      return NetworkImage(value);
    } else {
      return MemoryImage(base64Decode(value));
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

              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage: _getImageProvider(user?.profilePicture),
                child: _getImageProvider(user?.profilePicture) == null
                    ? const Icon(
                        Icons.account_circle_rounded,
                        color: Colors.black,
                        size: 100,
                      )
                    : null,
              ),

              const SizedBox(width: 20),

              if (!isLoading)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "${user?.firstName ?? ''} ${user?.lastName ?? ''}",
                          style: const TextStyle(
                            fontSize: 17,
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
                    if (user?.teacher != null)
                      Text(
                        "Email : ${user!.teacher!.email}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    if (user?.learner != null && user?.teacher != null)
                      Text(
                        "Learner & Teacher",
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      )
                    else if (user?.learner != null && user?.teacher == null)
                      Text(
                        "Learner",
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      )
                    else if (user?.learner == null && user?.teacher != null)
                      Text(
                        "Teacher",
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                    Row(
                      children: [
                        if (user?.teacher != null)
                          Row(
                            children: [
                              const Text(
                                "Teacher rate : 4.0",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              Icon(Icons.star, color: Colors.orange),
                            ],
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
          if (user?.teacher != null)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 228),
                  child: Text(
                    "${user!.teacher!.description}",
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 70),
              ],
            )
          else
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 130),
                  child: Text(
                    "This user doesn't have description",
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 70),
              ],
            ),
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AllClassesPage(myClasses: myClasses),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  "   See more",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const Icon(Icons.keyboard_arrow_right, color: Colors.black),
            ],
          ),
          if (user?.teacher != null)
            myClasses.isNotEmpty
                ? Column(
                    children: myClasses
                        .take(2)
                        .map(
                          (c) => ClassCard(
                            id: c.id,
                            className: c.className,
                            teacherName: c.teacherName,
                            rating: c.rating ?? 0.0,
                            enrolledLearner: 100, // replace with real data
                            imagePath:
                                "assets/images/guitar.jpg", // wait for real image
                          ),
                        )
                        .toList(),
                  )
                : const Text("No classes found for this teacher")
          else
            const SizedBox(height: 135),
        ],
      ),
    );
  }
}
