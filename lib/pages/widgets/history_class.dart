import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/profile/reviews_page.dart';

class ClassCard extends StatelessWidget {
  final int id;
  final String className;
  final String teacherName;
  final double rating;
  final int enrolledLearner;
  final String imagePath;

  const ClassCard({
    Key? key,
    required this.id,
    required this.className,
    required this.teacherName,
    required this.rating,
    required this.enrolledLearner,
    required this.imagePath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              bottomLeft: Radius.circular(15),
            ),
            child: Image.asset(
              imagePath,
              width: 120,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$className by $teacherName",
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        "Class rating : ",
                        style: TextStyle(fontSize: 13.0),
                      ),
                      const Icon(Icons.star, color: Colors.orange, size: 16),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Enrolled Learner : $enrolledLearner",
                    style: const TextStyle(fontSize: 13.0),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReviewPage(classId: id),
                          ),
                        );
                      },
                      child: const Text("Reviews",style: TextStyle(color: Colors.black),),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
