import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/widgets/cached_network_image.dart';
import 'package:tutorium_frontend/pages/widgets/history_class.dart';
import 'package:tutorium_frontend/service/classes.dart' as class_api;
import 'package:tutorium_frontend/service/teachers.dart' as teacher_api;
import 'package:tutorium_frontend/service/users.dart' as user_api;
import 'package:tutorium_frontend/service/rating_service.dart';
import 'package:tutorium_frontend/util/class_enrollment_pipeline.dart';
import 'package:tutorium_frontend/service/api_client.dart' show ApiException;
import 'package:tutorium_frontend/util/teacher_avatar_resolver.dart';

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
  final RatingService _ratingService = RatingService();
  final Map<int, double> _classRatings = {};
  double? _teacherAverageRating;
  TeacherAvatarSource _avatarSource = const TeacherAvatarSource.none();

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
      debugPrint(
        'DEBUG Teacher Data: id=${teacherData.id}, userId=${teacherData.userId}, description="${teacherData.description}", flagCount=${teacherData.flagCount}',
      );
      final user = await user_api.User.fetchById(teacherData.userId);
      final avatar = TeacherAvatarResolver.resolve(user.profilePicture);
      debugPrint('🖼️ Teacher avatar resolved: $avatar');
      var classes = await class_api.ClassInfo.fetchByTeacher(
        widget.teacherId,
        teacherName: user.firstName != null || user.lastName != null
            ? '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim()
            : null,
      );
      _classRatings.clear();

      final enrollmentCounts =
          await ClassEnrollmentPipeline.aggregateActiveEnrollments(classes);

      // Fetch ratings for all classes
      debugPrint('🌟 Loading ratings for ${classes.length} classes...');
      for (final classInfo in classes) {
        try {
          final rating = await _ratingService.getRating(classInfo.id);
          _classRatings[classInfo.id] = rating;
          debugPrint(
            '🌟 Class ${classInfo.id} (${classInfo.className}): rating=$rating',
          );
        } catch (e) {
          debugPrint('🌟 Failed to load rating for class ${classInfo.id}: $e');
          _classRatings[classInfo.id] = 0.0;
        }
      }

      final teacherAverageRating = await _ratingService.getTeacherRating(
        widget.teacherId,
      );
      debugPrint(
        '🌟 Teacher ${widget.teacherId} average rating: $teacherAverageRating',
      );

      classes = classes
          .map(
            (classInfo) => classInfo.copyWith(
              enrolledLearners:
                  enrollmentCounts[classInfo.id] ??
                  classInfo.enrolledLearners ??
                  0,
            ),
          )
          .toList();

      classes.sort((a, b) {
        final ratingA = _classRatings[a.id] ?? 0.0;
        final ratingB = _classRatings[b.id] ?? 0.0;
        return ratingB.compareTo(ratingA);
      });

      if (!mounted) return;

      setState(() {
        teacher = teacherData;
        teacherUser = user;
        teacherClasses = classes;
        _teacherAverageRating = teacherAverageRating;
        _avatarSource = avatar;
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

  Widget _buildAvatar() {
    switch (_avatarSource.type) {
      case TeacherAvatarType.network:
        return CachedCircularAvatar(
          imageUrl: _avatarSource.url!,
          radius: 50,
          backgroundColor: Colors.grey.shade200,
        );
      case TeacherAvatarType.memory:
        return CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: MemoryImage(_avatarSource.bytes!),
        );
      case TeacherAvatarType.none:
        return CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade200,
          child: Icon(Icons.person, size: 40, color: Colors.grey.shade500),
        );
    }
  }

  String _getTeacherDescription() {
    final description = teacher?.description;
    final trimmed = description?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    final fallback = teacherUser?.teacher?.description?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return "No description available";
  }

  String _formatTeacherRating() {
    final rating = _teacherAverageRating;
    if (rating == null || rating < 0) {
      return 'ยังไม่มีคะแนน';
    }
    return rating.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _ratingService.clearCache();
    if (teacher?.id != null) {
      _ratingService.clearTeacherCache(teacherId: teacher!.id!);
    } else {
      _ratingService.clearTeacherCache();
    }
    super.dispose();
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
                        _buildAvatar(),
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

                  // 🧾 About
                  const Text(
                    "About",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_getTeacherDescription()),

                  const SizedBox(height: 24),
                  const Divider(),

                  // 🚩 Flag Count
                  const Text(
                    "Flag Count",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text("${teacher!.flagCount}"),

                  const SizedBox(height: 24),
                  const Divider(),

                  // ⭐ Teacher Rating
                  const Text(
                    "Teacher Rating",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        _formatTeacherRating(),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),

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
                            for (final classInfo in displayedClasses)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: ClassCard(
                                  id: classInfo.id,
                                  className: classInfo.className,
                                  teacherName:
                                      classInfo.teacherName ??
                                      "${teacherUser!.firstName ?? ''} ${teacherUser!.lastName ?? ''}"
                                          .trim(),
                                  rating: _classRatings[classInfo.id] ?? 0.0,
                                  enrolledLearner: classInfo.enrolledLearners,
                                  imageUrl:
                                      classInfo.bannerPictureUrl ??
                                      classInfo.bannerPicture,
                                ),
                              ),

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
