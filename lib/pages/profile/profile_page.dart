import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:tutorium_frontend/pages/home/teacher/register/payment_screen.dart';
import 'package:tutorium_frontend/pages/profile/allClasses_page.dart';
import 'package:tutorium_frontend/pages/widgets/history_class.dart';
import 'package:tutorium_frontend/service/Users.dart' as user_api;
import 'package:tutorium_frontend/util/cache_user.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  user_api.User? user;
  List<Class> allClasses = [];
  List<Class> myClasses = [];
  bool isLoading = true;
  bool isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      // Get user ID from local storage
      final userId = await LocalStorage.getUserId();

      if (userId == null) {
        throw Exception('User ID not found in local storage');
      }

      // Get user from cache or fetch if needed
      final fetchedUser = await UserCache().getUser(
        userId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      setState(() {
        user = fetchedUser;
        isLoading = false;
      });

      debugPrint(
        "DEBUG ProfilePage: user loaded - ${user?.firstName} ${user?.lastName}",
      );
      debugPrint(
        "DEBUG ProfilePage: user id=${user?.id}, balance=${user?.balance}",
      );

      await fetchClasses(fetchedUser);
    } catch (e) {
      debugPrint("Error fetching user: $e");
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchClasses([user_api.User? currentUser]) async {
    try {
      final apiKey = dotenv.env["API_URL"];
      final port = dotenv.env["PORT"];

      final apiUrl = "$apiKey:$port/classes";
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        final fetchedClasses = jsonData.map((c) => Class.fromJson(c)).toList();

        if (!mounted) {
          return;
        }
        setState(() {
          allClasses = fetchedClasses;

          final profileUser = currentUser ?? user;
          if (profileUser?.teacher != null) {
            final fullName =
                "${profileUser?.firstName ?? ''} ${profileUser?.lastName ?? ''}"
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
      debugPrint("Error fetching classes: $e");
    }
  }

  Future<String?> pickImageAndConvertToBase64() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        return null;
      }

      final fileName = pickedFile.name.toLowerCase();
      const allowedExtensions = {'jpg', 'jpeg', 'png'};
      final extension = fileName.split('.').last;

      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('รองรับเฉพาะไฟล์ .jpg และ .png เท่านั้น'),
            ),
          );
        }
        return null;
      }

      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
      return 'data:$mimeType;base64,$base64String';
    } on PlatformException catch (e) {
      debugPrint('Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดคลังรูปภาพได้')),
        );
      }
    } catch (e) {
      debugPrint('Unexpected image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการเลือกรูป')),
        );
      }
    }
    return null;
  }

  Future<void> uploadProfilePicture(int userId, String base64Image) async {
    if (user == null) return;

    if (mounted) {
      setState(() {
        isUploadingImage = true;
      });
    } else {
      isUploadingImage = true;
    }

    try {
      final updatedUser = await user_api.User.update(
        userId,
        user_api.User(
          id: user!.id,
          studentId: user!.studentId,
          firstName: user!.firstName,
          lastName: user!.lastName,
          gender: user!.gender,
          phoneNumber: user!.phoneNumber,
          balance: user!.balance,
          banCount: user!.banCount,
          profilePicture: base64Image,
        ),
      );

      // Update cache with new user data
      UserCache().updateUser(updatedUser);

      if (mounted) {
        setState(() {
          user = updatedUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
        // Refresh user data to get the latest profile picture
        await fetchUser(forceRefresh: true);
      }
      debugPrint("Upload success");
    } catch (e) {
      debugPrint("Upload failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile picture')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploadingImage = false;
        });
      } else {
        isUploadingImage = false;
      }
    }
  }

  Future<void> _onProfileImageTap() async {
    if (isLoading || user == null || isUploadingImage) return;

    final base64Image = await pickImageAndConvertToBase64();
    if (base64Image != null) {
      await uploadProfilePicture(user!.id, base64Image);
    }
  }

  ImageProvider? _getImageProvider(String? value) {
    if (value == null || value.isEmpty) return null;

    if (value.startsWith("http")) {
      return NetworkImage(value);
    } else {
      try {
        final payload = value.startsWith('data:image')
            ? value.substring(value.indexOf(',') + 1)
            : value;
        return MemoryImage(base64Decode(payload));
      } catch (e) {
        debugPrint('Failed to decode profile image: $e');
        return null;
      }
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
                  GestureDetector(
                    onTap: () async {
                      if (isLoading || user == null) return;
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(userId: user!.id),
                        ),
                      );

                      // Refresh user data if payment was successful
                      if (result == true) {
                        await fetchUser(forceRefresh: true);
                      }
                    },
                    child: const Icon(
                      Icons.add_circle_rounded,
                      color: Colors.grey,
                      size: 25,
                    ),
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

              GestureDetector(
                onTap: _onProfileImageTap,
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _getImageProvider(
                          user?.profilePicture,
                        ),
                        child: _getImageProvider(user?.profilePicture) == null
                            ? const Icon(
                                Icons.account_circle_rounded,
                                color: Colors.black,
                                size: 100,
                              )
                            : null,
                      ),
                      if (isUploadingImage)
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.fromRGBO(0, 0, 0, 0.4),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.black54,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                            enrolledLearner: 100,
                            // replace with real data
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
