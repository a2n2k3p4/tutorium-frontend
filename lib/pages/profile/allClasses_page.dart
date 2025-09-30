import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/widgets/history_class.dart';
import 'package:tutorium_frontend/pages/profile/profile_page.dart';

class AllClassesPage extends StatelessWidget {
  final List<Class> myClasses;

  const AllClassesPage({super.key, required this.myClasses});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Classes")),
      body: myClasses.isNotEmpty
          ? ListView.builder(
              itemCount: myClasses.length,
              itemBuilder: (context, index) {
                final c = myClasses[index];
                return ClassCard(
                  id: c.id,
                  className: c.className,
                  teacherName: c.teacherName,
                  rating: c.rating ?? 0.0,
                  enrolledLearner: 100, // replace with real data
                  imagePath: "assets/images/guitar.jpg", // wait for real image
                );
              },
            )
          : const Center(child: Text("No classes found")),
    );
  }
}
