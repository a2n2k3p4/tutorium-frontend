import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/profile/reviews_page.dart';

class ClassCard extends StatelessWidget {
  final int id;
  final String className;
  final String teacherName;
  final double rating;
  final int? enrolledLearner;
  final String? imageUrl;

  const ClassCard({
    super.key,
    required this.id,
    required this.className,
    required this.teacherName,
    required this.rating,
    this.enrolledLearner,
    this.imageUrl,
  });

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
            child: _buildPreviewImage(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    className,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (teacherName.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      teacherName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
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
                    "Enrolled Learner : ${enrolledLearner ?? '-'}",
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
                      child: const Text(
                        "Reviews",
                        style: TextStyle(color: Colors.black),
                      ),
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

  Widget _buildPreviewImage() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholderImage();
    }

    return Image.network(
      imageUrl!,
      width: 120,
      height: 160,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: 120,
          height: 160,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                        (progress.expectedTotalBytes ?? 1)
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 120,
      height: 160,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.photo_library_outlined,
        color: Colors.grey.shade500,
        size: 32,
      ),
    );
  }
}
