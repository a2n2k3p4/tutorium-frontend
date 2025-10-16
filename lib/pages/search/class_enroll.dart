import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/pages/profile/teacher_profile.dart';
import 'package:tutorium_frontend/pages/widgets/class_session_service.dart';

class Review {
  final int? id;
  final int? classId;
  final int? learnerId;
  final int? userId;
  final int? rating;
  final String? comment;

  Review({
    this.id,
    this.classId,
    this.learnerId,
    this.userId,
    this.rating,
    this.comment,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: int.tryParse(json['ID']?.toString() ?? '0'),
      classId: int.tryParse(json['class_id']?.toString() ?? '0'),
      learnerId: int.tryParse(json['learner_id']?.toString() ?? '0'),
      userId: int.tryParse(
        (json['Learner'] != null ? json['Learner']['user_id'] : '0').toString(),
      ),
      rating: int.tryParse(json['rating']?.toString() ?? '0'),
      comment: json['comment'],
    );
  }
}

class User {
  final int id;
  final String firstName;
  final String lastName;

  User({required this.id, required this.firstName, required this.lastName});

  factory User.fromJson(Map<String, dynamic> json) {
    final idValue = json['ID'] ?? json['id'] ?? 0;
    return User(
      id: (idValue is String) ? int.tryParse(idValue) ?? 0 : idValue,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
    );
  }

  String get fullName => "$firstName $lastName".trim();
}

class ClassEnrollPage extends StatefulWidget {
  final int classId;
  final String teacherName;
  final double rating;

  const ClassEnrollPage({
    super.key,
    required this.classId,
    required this.teacherName,
    required this.rating,
  });

  @override
  State<ClassEnrollPage> createState() => _ClassEnrollPageState();
}

class _ClassEnrollPageState extends State<ClassEnrollPage> {
  ClassSession? selectedSession;
  ClassInfo? classInfo;
  UserInfo? userInfo;
  List<ClassSession> sessions = [];
  List<Review> reviews = [];
  List<User> users = [];
  Map<int, User> usersMap = {};
  bool isLoadingReviews = true;
  bool isLoading = true;
  bool showAllReviews = false;
  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  Future<void> loadAllData() async {
    try {
      setState(() {
        isLoading = true;
        isLoadingReviews = true;
        hasError = false;
      });

      await Future.wait([fetchClassData(), fetchReviews()]);
      await fetchUsers(); // fetch after reviews

      setState(() {
        isLoading = false;
        isLoadingReviews = false;
      });
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = "Failed to load data: $e";
      });
      debugPrint("Error loading data: $e");
    }
  }

  Future<void> fetchClassData() async {
    final fetchedSessions = await ClassSessionService().fetchClassSessions(
      widget.classId,
    );
    final fetchedClassInfo = await ClassSessionService().fetchClassInfo(
      widget.classId,
    );
    final fetchedUserInfo = await ClassSessionService().fetchUser();

    setState(() {
      sessions = fetchedSessions;
      classInfo = fetchedClassInfo;
      userInfo = fetchedUserInfo;
    });
  }

  Future<void> fetchReviews() async {
    try {
      final apiKey = dotenv.env["API_URL"];
      final port = dotenv.env["PORT"];
      final apiUrl = "$apiKey:$port/reviews";

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        final allReviews = jsonData.map((r) => Review.fromJson(r)).toList();
        final filteredReviews = allReviews
            .where((r) => (r.classId ?? -1) == widget.classId)
            .toList();

        setState(() {
          reviews = filteredReviews;
        });

        debugPrint(
          "🎯 Filtered ${filteredReviews.length}/${allReviews.length} reviews for class ${widget.classId}",
        );
      } else {
        throw Exception("Failed to load reviews: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
      setState(() {
        reviews = [];
      });
    }
  }

  Future<void> fetchUsers() async {
    try {
      final apiKey = dotenv.env["API_URL"];
      final port = dotenv.env["PORT"];

      // Collect unique user IDs from all reviews
      final userIds = reviews
          .map((r) => r.userId)
          .where((id) => id != null && id != 0)
          .toSet()
          .toList();

      if (userIds.isEmpty) {
        debugPrint("⚠️ No user IDs found in reviews");
        return;
      }

      final Map<int, User> fetchedUsers = {};

      // Fetch each user by ID
      for (final id in userIds) {
        final apiUrl = "$apiKey:$port/users/$id";
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          final user = User.fromJson(jsonData);
          fetchedUsers[user.id] = user;
        } else {
          debugPrint("⚠️ Failed to fetch user $id: ${response.statusCode}");
        }
      }

      setState(() {
        usersMap = fetchedUsers;
      });

      debugPrint("👥 Loaded ${usersMap.length} users for reviews");
    } catch (e) {
      debugPrint("❌ Error fetching users: $e");
    }
  }

  String getUserName(Review review) {
    if (review.userId == null) return "Unknown User";
    final user = usersMap[review.userId!];
    return user?.fullName ?? "Unknown User";
  }

  String _formatDate(DateTime dt) {
    const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}";
  }

  String _formatTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = pad(dt.minute);
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $ampm";
  }

  Widget _buildSessionDropdown() {
    if (sessions.isEmpty) return const Text("No sessions available");

    return DropdownButton<ClassSession>(
      isExpanded: true,
      hint: const Text("Choose a session"),
      value: selectedSession,
      items: sessions.map((session) {
        final dateStr = _formatDate(session.classStart);
        final timeStr =
            "${_formatTime(session.classStart)} – ${_formatTime(session.classFinish)}";
        final deadlineStr = _formatDate(session.enrollmentDeadline);

        return DropdownMenuItem(
          value: session,
          child: Text(
            "$dateStr • $timeStr • \$${session.price}  (Deadline: $deadlineStr)",
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedSession = value;
        });
      },
    );
  }

  Widget _buildReviewsSection() {
    if (isLoadingReviews || usersMap.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reviews.isEmpty) {
      return const Text("No reviews yet");
    }

    return Column(
      children: [
        ...reviews.take(showAllReviews ? reviews.length : 2).map((review) {
          final reviewerName = getUserName(review);

          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.greenAccent,
              radius: 20,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              reviewerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  review.comment?.isNotEmpty == true
                      ? review.comment!
                      : "(No comment)",
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < (review.rating ?? 0)
                            ? Icons.star
                            : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${(review.rating ?? 0).toDouble().toStringAsFixed(1)}/5.0",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        if (reviews.length > 2)
          TextButton(
            onPressed: () {
              setState(() {
                showAllReviews = !showAllReviews;
              });
            },
            child: Text(showAllReviews ? "See Less" : "See More"),
          ),
      ],
    );
  }

  void _showEnrollConfirmationDialog(BuildContext context) {
    if (selectedSession == null || userInfo == null) return;

    final hasEnoughBalance = userInfo!.balance >= selectedSession!.price;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Enrollment"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Class: ${classInfo?.name ?? "Unknown"}"),
              Text("Session: ${selectedSession!.description}"),
              Text("Price: \$${selectedSession!.price.toStringAsFixed(2)}"),
              const SizedBox(height: 12),
              if (hasEnoughBalance)
                const Icon(Icons.check_circle, color: Colors.green, size: 48)
              else
                const Icon(Icons.cancel, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              hasEnoughBalance
                  ? const Text("Your balance is enough to enroll ✅")
                  : Text(
                      "Not enough balance ❌\nYour balance: \$${userInfo!.balance}\nNeeded: \$${selectedSession!.price}",
                      textAlign: TextAlign.center,
                    ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            if (hasEnoughBalance)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Successfully enrolled in ${selectedSession!.description} 🎉",
                      ),
                    ),
                  );
                },
                child: const Text("Confirm"),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Redirecting to Balance Page..."),
                    ),
                  );
                },
                child: const Text("Add Balance"),
              ),
          ],
        );
      },
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.asset(
                    "assets/images/guitar.jpg",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : hasError
                      ? Column(
                          children: [
                            const Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Error loading class data",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(errorMessage),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: loadAllData,
                              child: const Text("Retry"),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "🎨 ${classInfo?.name ?? "Untitled Class"}",
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text("${widget.rating}/5"),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              classInfo?.description ??
                                  "No description available",
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "👨‍🏫 Teacher: ${widget.teacherName}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (classInfo != null &&
                                        classInfo!.teacher_id != 0) {
                                      final teacherId = classInfo!.teacher_id;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              TeacherProfilePage(
                                                teacherId: teacherId,
                                              ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Teacher ID not found for ${widget.teacherName}",
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text("View Profile"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "📂 Category: ${classInfo?.categories ?? "General"}",
                            ),
                            const Divider(height: 32),
                            const Text(
                              "📅 Select Session",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildSessionDropdown(),
                            const Divider(height: 32),
                            const Text(
                              "⭐ Reviews",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildReviewsSection(),
                          ],
                        ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: selectedSession == null
                    ? null
                    : () => _showEnrollConfirmationDialog(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Enroll Now"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
