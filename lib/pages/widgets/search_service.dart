import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SearchService {
  final String baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

  Future<List<dynamic>> getAllClasses() async {
    try {
      final url = Uri.parse("$baseUrl/classes");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  List<dynamic> searchLocal(List<dynamic> allClasses, String query) {
    final filtered = query.isEmpty
        ? List<dynamic>.from(allClasses)
        : allClasses.where((c) {
            final name = (c["class_name"] ?? "").toString().toLowerCase();
            final desc = (c["class_description"] ?? "")
                .toString()
                .toLowerCase();
            final teacher = (c["teacher_name"] ?? "").toString().toLowerCase();
            final q = query.trim().toLowerCase();
            return name.contains(q) || desc.contains(q) || teacher.contains(q);
          }).toList();

    filtered.sort((a, b) {
      final ratingA = (a["rating"] ?? 0).toDouble();
      final ratingB = (b["rating"] ?? 0).toDouble();
      return ratingB.compareTo(ratingA);
    });

    return filtered;
  }

  Future<List<dynamic>> filterClasses({
    List<String>? categories,
    num? minRating,
    num? maxRating,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/classes");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is List<dynamic>) {
          List<dynamic> data = body;

          if (minRating != null) {
            data = data.where((c) {
              final rating = (c["rating"] is num) ? (c["rating"] as num).toDouble() : 0.0;
              return rating >= minRating;
            }).toList();
          }
          if (maxRating != null) {
            data = data.where((c) {
              final rating = (c["rating"] is num) ? (c["rating"] as num).toDouble() : 0.0;
              return rating <= maxRating;
            }).toList();
          }
          if (categories != null && categories.isNotEmpty && !categories.contains("All")) {
            data = data.where((c) {
              final List<dynamic> classCategories = c["Categories"] ?? [];
              return classCategories.any((cat) => categories.contains(cat));
            }).toList();
          }
          data.sort((a, b) {
            final ratingA = (a["rating"] is num) ? (a["rating"] as num).toDouble() : 0.0;
            final ratingB = (b["rating"] is num) ? (b["rating"] as num).toDouble() : 0.0;
            return ratingB.compareTo(ratingA);
          });
          return data;
        }
      }
      return [];
    } catch (e) {
      print("Error filtering classes: $e");
      return [];
    }
  }
}