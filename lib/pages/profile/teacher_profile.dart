import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/widgets/history_class.dart';
import 'package:tutorium_frontend/service/classes.dart' as class_api;
import 'package:tutorium_frontend/service/teachers.dart' as teacher_api;
import 'package:tutorium_frontend/service/users.dart' as user_api;
import 'package:tutorium_frontend/service/api_client.dart' show ApiException;

class TeacherProfilePage extends StatefulWidget {
  final int teacherId;

  const TeacherProfilePage({super.key, required this.teacherId});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  user_api.User? teacherUser;
  teacher_api.Teacher? teacher;
  List<class_api.ClassInfo> teacherClasses = [];
  bool isLoading = true;
  bool showAllClasses = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    } else {
      isLoading = true;
      errorMessage = null;
    }

    try {
      final teacherData = await teacher_api.Teacher.fetchById(widget.teacherId);
      final user = await user_api.User.fetchById(teacherData.userId);
      final classes = await class_api.ClassInfo.fetchAll(
        teacherId: widget.teacherId,
      );

      classes.sort((a, b) => b.rating.compareTo(a.rating));

      if (!mounted) return;

      setState(() {
        teacher = teacherData;
        teacherUser = user;
        teacherClasses = classes;
        isLoading = false;
      });
    } on ApiException catch (e) {
      debugPrint('Error loading teacher profile (API): $e');
      if (mounted) {
        setState(() {
          errorMessage = 'ไม่สามารถโหลดข้อมูลผู้สอนได้ (${e.statusCode})';
          teacherClasses = [];
          isLoading = false;
        });
      } else {
        errorMessage = 'ไม่สามารถโหลดข้อมูลผู้สอนได้ (${e.statusCode})';
        teacherClasses = [];
        isLoading = false;
      }
    } catch (e) {
      debugPrint('Error loading teacher profile: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูลผู้สอน';
          teacherClasses = [];
          isLoading = false;
        });
      } else {
        errorMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูลผู้สอน';
        teacherClasses = [];
        isLoading = false;
      }
    }
  }

  ImageProvider<Object>? _avatarImageProvider() {
    final source = teacherUser?.profilePicture;
    if (source == null || source.isEmpty) {
      return null;
    }

    if (source.startsWith('http')) {
      return NetworkImage(source);
    }

    try {
      final payload = source.startsWith('data:image')
          ? source.substring(source.indexOf(',') + 1)
          : source;
      final bytes = base64Decode(payload);
      return MemoryImage(bytes);
    } catch (e) {
      debugPrint('Failed to decode teacher avatar: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedClasses = showAllClasses
        ? teacherClasses
        : teacherClasses.take(2).toList();
    final avatarProvider = _avatarImageProvider();

    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Profile")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : (teacherUser == null || teacher == null)
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
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey.shade500,
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "${teacherUser!.firstName ?? ''} ${teacherUser!.lastName ?? ''}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          teacherUser!.gender ?? "Gender not specified",
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
                  Text("Email: ${teacher?.email ?? '-'}"),
                  const SizedBox(height: 8),
                  Text(
                    teacher?.description?.isNotEmpty == true
                        ? teacher!.description
                        : "No description",
                  ),

                  const SizedBox(height: 24),
                  const Divider(),

                  // ☎️ Contact Info
                  const Text(
                    "📞 Contact Info",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text("Phone: ${teacherUser!.phoneNumber ?? '-'}"),
                  const SizedBox(height: 4),
                  Text("Ban Count: ${teacherUser!.banCount}"),

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
                              final teacherName =
                                  classInfo.teacherName ??
                                  "${teacherUser!.firstName ?? ''} ${teacherUser!.lastName ?? ''}"
                                      .trim();
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: ClassCard(
                                  id: classInfo.id,
                                  className: classInfo.className,
                                  teacherName: teacherName.isEmpty
                                      ? 'ไม่ทราบชื่อผู้สอน'
                                      : teacherName,
                                  rating: classInfo.rating,
                                  enrolledLearner: classInfo.enrolledLearners,
                                  imageUrl: (() {
                                    final image =
                                        classInfo.bannerPictureUrl ??
                                        classInfo.bannerPicture;
                                    if (image == null || image.isEmpty) {
                                      return null;
                                    }
                                    return image;
                                  })(),
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
