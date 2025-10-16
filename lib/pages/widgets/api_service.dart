import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiService {
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

  Future<List<dynamic>> searchClass(String query) async {
    final queryParams = {"class_description": query, "class_name": query};

    final url = Uri.parse(
      "$baseUrl/classes",
    ).replace(queryParameters: queryParams);

    print("Search request: $url");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to search classes");
    }
  }

  Future<List<dynamic>> filterClasses({
    List<String>? categories,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    double? maxRating,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (categories != null && categories.isNotEmpty) {
      queryParams["category"] = categories.join(",");
    }

    if (minPrice != null) queryParams["min_price"] = minPrice.toString();
    if (maxPrice != null) queryParams["max_price"] = maxPrice.toString();
    if (minRating != null) queryParams["min_rating"] = minRating.toString();
    if (maxRating != null) queryParams["max_rating"] = maxRating.toString();
    if (search != null && search.isNotEmpty) queryParams["search"] = search;

    final uri = Uri.parse(
      "$baseUrl/classes",
    ).replace(queryParameters: queryParams);

    print("Filter request: $uri");

    final response = await http.get(uri);
    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      print("Filter success — found ${result.length} classes");
      return result;
    } else {
      print("Filter failed: ${response.statusCode}");
      throw Exception("Failed to filter classes (${response.statusCode})");
    }
  }
}
