import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SearchService {
  final String baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

  Future<List<dynamic>> getAllClasses() async {
    final url = Uri.parse("$baseUrl/classes");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load classes");
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
    num? minPrice,
    num? maxPrice,
    num? minRating,
    num? maxRating,
  }) async {
    final queryParams = <String, String>{};

    if (minPrice != null) queryParams["min_price"] = minPrice.toString();
    if (maxPrice != null) queryParams["max_price"] = maxPrice.toString();
    if (minRating != null) queryParams["min_rating"] = minRating.toString();
    if (maxRating != null) queryParams["max_rating"] = maxRating.toString();

    if (categories != null && categories.isNotEmpty) {
      final filteredCategories = categories.where((c) => c != "All").toList();
      if (filteredCategories.isNotEmpty) {
        for (var c in filteredCategories) {
          queryParams["category"] = c;
        }
      }
    }

    final uri = Uri.parse(
      "$baseUrl/classes",
    ).replace(queryParameters: queryParams);

    print("Filter request: $uri");

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

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
    } else {
      throw Exception("Failed to filter classes (${response.statusCode})");
    }
  }
}
