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
      final queryParams = <String, String>{};
      if (categories != null && categories.isNotEmpty) {
        final filteredCategories = categories.where((c) => c != "All").toList();
        if (filteredCategories.isNotEmpty) {
          queryParams["category"] = filteredCategories.join(",");
        }
      }

      if (minRating != null) queryParams["min_rating"] = minRating.toString();
      if (maxRating != null) queryParams["max_rating"] = maxRating.toString();

      final uri = Uri.parse(
        "$baseUrl/classes",
      ).replace(queryParameters: queryParams);
      print("Filter request: $uri");

      final response = await http.get(uri);
      print("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is List) {
          final data = List<Map<String, dynamic>>.from(body);
          data.sort((a, b) {
            final ratingA = (a["rating"] is num)
                ? (a["rating"] as num).toDouble()
                : 0.0;
            final ratingB = (b["rating"] is num)
                ? (b["rating"] as num).toDouble()
                : 0.0;
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

  Future<List<dynamic>> getPopularClasses({int? limit}) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/classes",
      ).replace(queryParameters: {"sort": "popular"});

      print("Popular classes request: $uri");

      final response = await http.get(uri);
      print("Popular classes status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final body = json.decode(response.body);

        if (body is List) {
          final data = List<Map<String, dynamic>>.from(body);
          data.sort((a, b) {
            final ratingA = (a["rating"] ?? 0).toDouble();
            final ratingB = (b["rating"] ?? 0).toDouble();
            return ratingB.compareTo(ratingA);
          });

          if (limit != null && data.length > limit) {
            return data.take(limit).toList();
          }
          return data;
        }
      }

      return [];
    } catch (e) {
      print("Error fetching popular classes: $e");
      return [];
    }
  }
}
