import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/widgets/history_class.dart';
import 'package:tutorium_frontend/service/classes.dart' as class_api;

class AllClassesPage extends StatelessWidget {
  final List<class_api.ClassInfo> myClasses;
  final String? errorMessage;

  const AllClassesPage({super.key, required this.myClasses, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Classes")),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Builder(
          builder: (context) {
            if (errorMessage != null && errorMessage!.isNotEmpty) {
              return Center(
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
              );
            }

            if (myClasses.isEmpty) {
              return const Center(child: Text("No classes found"));
            }

            return ListView.builder(
              itemCount: myClasses.length,
              itemBuilder: (context, index) {
                final c = myClasses[index];
                final teacherName = c.teacherName?.trim().isNotEmpty == true
                    ? c.teacherName!
                    : '';
                final image = c.bannerPictureUrl ?? c.bannerPicture;
                return ClassCard(
                  id: c.id,
                  className: c.className,
                  teacherName: teacherName.isEmpty
                      ? 'ไม่ทราบชื่อผู้สอน'
                      : teacherName,
                  rating: c.rating,
                  enrolledLearner: c.enrolledLearners,
                  imageUrl: image == null || image.isEmpty ? null : image,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
