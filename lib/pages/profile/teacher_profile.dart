import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/pages/widgets/class_session_service.dart';
import 'package:tutorium_frontend/pages/widgets/history_class.dart';

class TeacherProfilePage extends StatefulWidget {
  final int teacherId;

  const TeacherProfilePage({super.key, required this.teacherId});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  UserInfo? userInfo;
  Map<String, dynamic>? teacherInfo;
  List<ClassInfo> teacherClasses = [];
  bool isLoading = true;
  bool showAllClasses = false;

  final baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final teacherUrl = Uri.parse("$baseUrl/teachers/${widget.teacherId}");
      final teacherRes = await http.get(teacherUrl);
      if (teacherRes.statusCode != 200)
        throw Exception("Failed to load teacher");

      final teacherData = json.decode(teacherRes.body);
      final userId = teacherData["user_id"];

      final userUrl = Uri.parse("$baseUrl/users/$userId");
      final userRes = await http.get(userUrl);
      if (userRes.statusCode != 200)
        throw Exception("Failed to load user info");

      final userData = json.decode(userRes.body);
      final user = UserInfo.fromJson(userData);

      final classUrl = Uri.parse(
        "$baseUrl/classes?teacher_id=${widget.teacherId}",
      );
      final classRes = await http.get(classUrl);

      List<ClassInfo> classes = [];
      if (classRes.statusCode == 200) {
        final data = json.decode(classRes.body);
        if (data is List) {
          classes = data.map((e) => ClassInfo.fromJson(e)).toList();
        }
      }

      // 🧠 Sort by highest rating first
      classes.sort((a, b) => b.rating.compareTo(a.rating));

      setState(() {
        teacherInfo = teacherData;
        userInfo = user;
        teacherClasses = classes;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading teacher profile: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedClasses = showAllClasses
        ? teacherClasses
        : teacherClasses.take(2).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Profile")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (userInfo == null || teacherInfo == null)
          ? const Center(child: Text("Teacher not found"))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👤 Avatar and Name
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          backgroundImage: AssetImage(
                            "assets/images/profile_placeholder.png",
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "${userInfo!.firstName ?? ''} ${userInfo!.lastName ?? ''}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          userInfo!.gender ?? "Gender not specified",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),

                  // 🧾 Teacher Info
                  const Text(
                    "📧 About the Teacher",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text("Email: ${teacherInfo!["email"] ?? '-'}"),
                  const SizedBox(height: 8),
                  Text(teacherInfo!["description"] ?? "No description"),

                  const SizedBox(height: 24),
                  const Divider(),

                  // ☎️ Contact Info
                  const Text(
                    "📞 Contact Info",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text("Phone: ${userInfo!.phoneNumber ?? '-'}"),
                  const SizedBox(height: 4),
                  Text("Ban Count: ${userInfo!.banCount}"),

                  const SizedBox(height: 24),
                  const Divider(),

                  // 🎓 Classes
                  const Text(
                    "📚 Classes by this Teacher",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  teacherClasses.isEmpty
                      ? const Text("This teacher has no classes yet.")
                      : Column(
                          children: [
                            ...displayedClasses.map((classInfo) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: ClassCard(
                                  id: classInfo.id,
                                  className: classInfo.name,
                                  teacherName: classInfo.teacherName,
                                  rating: classInfo.rating,
                                  enrolledLearner: 100, // placeholder
                                  imagePath: "assets/images/guitar.jpg",
                                ),
                              );
                            }).toList(),

                            // 👇 See more / less
                            if (teacherClasses.length > 2)
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      showAllClasses = !showAllClasses;
                                    });
                                  },
                                  child: Text(
                                    showAllClasses
                                        ? "See less ▲"
                                        : "See more ▼",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ],
              ),
            ),
    );
  }
}
