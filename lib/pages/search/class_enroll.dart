import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/pages/home/teacher/register/payment_screen.dart';
import 'package:tutorium_frontend/pages/profile/teacher_profile.dart';
import 'package:tutorium_frontend/pages/widgets/class_session_service.dart';
import 'package:tutorium_frontend/service/Enrollments.dart' as enrollment_api;
import 'package:tutorium_frontend/service/Notifications.dart'
    as notification_api;
import 'package:tutorium_frontend/service/Users.dart' as user_api;
import 'package:tutorium_frontend/util/cache_user.dart';
import 'package:tutorium_frontend/util/local_storage.dart';

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
  bool isProcessingEnrollment = false;

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
      await fetchUsers();

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
    final previousSelectedId = selectedSession?.id;
    final service = ClassSessionService();

    final fetchedSessions = await service.fetchClassSessions(widget.classId);
    final fetchedClassInfo = await service.fetchClassInfo(widget.classId);

    UserInfo? fetchedUserInfo;
    try {
      fetchedUserInfo = await service.fetchUser();
    } catch (e) {
      debugPrint('⚠️ Failed to fetch user info: $e');
    }

    if (fetchedUserInfo != null) {
      if (fetchedUserInfo.learnerId != null) {
        await LocalStorage.saveLearnerId(fetchedUserInfo.learnerId!);
      }

      final cachedBalance = await LocalStorage.getUserBalance();
      final latestBalance = _roundToCents(fetchedUserInfo.balance);

      if (cachedBalance == null ||
          (cachedBalance - latestBalance).abs() > 0.009) {
        await LocalStorage.saveUserBalance(latestBalance);
      }

      final balanceToUse = await LocalStorage.getUserBalance() ?? latestBalance;
      fetchedUserInfo = fetchedUserInfo.copyWith(balance: balanceToUse);
    } else {
      final cachedBalance = await LocalStorage.getUserBalance();
      if (cachedBalance != null && userInfo != null) {
        fetchedUserInfo = userInfo!.copyWith(balance: cachedBalance);
      }
    }

    ClassSession? restoredSelection;
    if (previousSelectedId != null) {
      for (final session in fetchedSessions) {
        if (session.id == previousSelectedId) {
          restoredSelection = session;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      sessions = fetchedSessions;
      classInfo = fetchedClassInfo;
      userInfo = fetchedUserInfo;
      selectedSession = restoredSelection;
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
            '${dateStr} • ${timeStr} • \$${session.price.toStringAsFixed(2)}  (Deadline: $deadlineStr)',
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

  Future<int?> _ensureLearnerId() async {
    if (userInfo?.learnerId != null) {
      await LocalStorage.saveLearnerId(userInfo!.learnerId!);
      return userInfo!.learnerId;
    }

    final cachedLearnerId = await LocalStorage.getLearnerId();
    if (cachedLearnerId != null) {
      if (mounted && userInfo != null) {
        setState(() {
          userInfo = userInfo!.copyWith(learnerId: cachedLearnerId);
        });
      }
      return cachedLearnerId;
    }

    try {
      final userId = await LocalStorage.getUserId();
      if (userId == null) return null;
      final freshUser = await user_api.User.fetchById(userId);
      final learner = freshUser.learner;
      if (learner != null) {
        await LocalStorage.saveLearnerId(learner.id);
        if (mounted && userInfo != null) {
          setState(() {
            userInfo = userInfo!.copyWith(learnerId: learner.id);
          });
        }
        return learner.id;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to resolve learner id: $e');
    }

    return null;
  }

  Future<void> _handleEnrollment(BuildContext parentContext) async {
    if (selectedSession == null) return;

    final learnerId = await _ensureLearnerId();
    if (learnerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to find learner information. Please relogin.',
            ),
          ),
        );
      }
      return;
    }

    final session = selectedSession!;
    final currentUser = userInfo;

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(content: Text('User information unavailable.')),
        );
      }
      return;
    }

    if (currentUser.balance < session.price) {
      if (mounted) {
        ScaffoldMessenger.of(
          parentContext,
        ).showSnackBar(const SnackBar(content: Text('Insufficient balance.')));
      }
      return;
    }

    if (mounted) {
      setState(() {
        isProcessingEnrollment = true;
      });
    }

    try {
      // ตรวจสอบว่าลงทะเบียนซ้ำหรือไม่ก่อนหักเงิน
      final existingEnrollments = await enrollment_api.Enrollment.fetchAll();
      final isDuplicate = existingEnrollments.any(
        (e) => e.learnerId == learnerId && e.classSessionId == session.id,
      );

      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(
              content: Text('You are already enrolled in this session.'),
            ),
          );
        }
        return;
      }

      // ถ้าไม่ซ้ำ ค่อยหักเงิน
      final originalBalance = currentUser.balance;
      final deductedBalance = _roundToCents(originalBalance - session.price);
      bool balanceDeducted = false;
      user_api.User? updatedServerUser;

      try {
        updatedServerUser = await _updateRemoteUserBalance(
          userId: currentUser.id,
          balance: deductedBalance,
        );
        balanceDeducted = true;

        final enrollment = enrollment_api.Enrollment(
          classSessionId: session.id,
          enrollmentStatus: 'active',
          learnerId: learnerId,
        );

        await enrollment_api.Enrollment.create(enrollment);
      } catch (e) {
        debugPrint('❌ Enrollment flow failed: $e');

        if (balanceDeducted) {
          try {
            await _updateRemoteUserBalance(
              userId: currentUser.id,
              balance: originalBalance,
            );
          } catch (restoreError) {
            debugPrint(
              '⚠️ Failed to restore balance after enrollment error: $restoreError',
            );
          }

          if (mounted) {
            setState(() {
              userInfo = currentUser.copyWith(
                balance: originalBalance,
                learnerId: learnerId,
              );
            });
          }
        }

        if (mounted) {
          final message = balanceDeducted
              ? 'Failed to enroll. We restored your balance.'
              : 'Unable to deduct balance. Please try again.';
          ScaffoldMessenger.of(
            parentContext,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }

      if (mounted) {
        setState(() {
          userInfo = currentUser.copyWith(
            balance: updatedServerUser?.balance ?? deductedBalance,
            learnerId: learnerId,
          );
        });
      }

      await fetchClassData();

      await _createEnrollmentNotification(
        userId: currentUser.id,
        session: session,
        learnerId: learnerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Successfully enrolled in ${session.description} 🎉'),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Enrollment check failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(content: Text('Failed to process enrollment.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessingEnrollment = false;
        });
      }
    }
  }

  double _roundToCents(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded < 0 ? 0 : rounded;
  }

  Future<user_api.User> _updateRemoteUserBalance({
    required int userId,
    required double balance,
  }) async {
    user_api.User? baseUser = UserCache().user;
    if (baseUser == null || baseUser.id != userId) {
      baseUser = await user_api.User.fetchById(userId);
    }

    final payloadUser = user_api.User(
      id: baseUser.id,
      studentId: baseUser.studentId,
      firstName: baseUser.firstName,
      lastName: baseUser.lastName,
      gender: baseUser.gender,
      phoneNumber: baseUser.phoneNumber,
      balance: balance,
      banCount: baseUser.banCount,
      profilePicture: baseUser.profilePicture,
      teacher: baseUser.teacher,
      learner: baseUser.learner,
    );

    final serverUser = await user_api.User.update(userId, payloadUser);
    UserCache().saveUser(serverUser);
    await LocalStorage.saveUserBalance(serverUser.balance);
    return serverUser;
  }

  Future<void> _createEnrollmentNotification({
    required int userId,
    required ClassSession session,
    required int learnerId,
  }) async {
    final className = classInfo?.name ?? session.description;
    final description =
        'Enrollment confirmed for $className (Session: ${session.description}) [Learner #$learnerId].';

    final notification = notification_api.NotificationModel(
      notificationDate: DateTime.now().toUtc(),
      notificationDescription: description,
      notificationType: 'Enrollment',
      readFlag: false,
      userId: userId,
    );

    try {
      await notification_api.NotificationModel.create(notification);
    } catch (e) {
      debugPrint('⚠️ Failed to create enrollment notification: $e');
    }
  }

  Future<void> _showEnrollConfirmationDialog(BuildContext parentContext) async {
    if (isProcessingEnrollment || selectedSession == null) return;

    final cachedBalance = await LocalStorage.getUserBalance();
    if (mounted && cachedBalance != null && userInfo != null) {
      setState(() {
        userInfo = userInfo!.copyWith(balance: cachedBalance);
      });
    }

    final currentUser = userInfo;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(content: Text('User information unavailable.')),
        );
      }
      return;
    }

    final hasEnoughBalance = currentUser.balance >= selectedSession!.price;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
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
                      "Not enough balance ❌\n"
                      "Your balance: \$${currentUser.balance.toStringAsFixed(2)}\n"
                      "Needed: \$${selectedSession!.price.toStringAsFixed(2)}",
                      textAlign: TextAlign.center,
                    ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            if (hasEnoughBalance)
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _handleEnrollment(parentContext);
                },
                child: const Text("Confirm"),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final result = await Navigator.of(parentContext).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(userId: currentUser.id),
                    ),
                  );
                  if (result == true) {
                    await fetchClassData();
                  } else {
                    final latestBalance = await LocalStorage.getUserBalance();
                    if (mounted && latestBalance != null) {
                      setState(() {
                        userInfo = currentUser.copyWith(balance: latestBalance);
                      });
                    }
                  }
                },
                child: const Text("Add Balance"),
              ),
          ],
        );
      },
    );
  }

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
                onPressed: (selectedSession == null || isProcessingEnrollment)
                    ? null
                    : () => _showEnrollConfirmationDialog(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: isProcessingEnrollment
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text("Enroll Now"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
