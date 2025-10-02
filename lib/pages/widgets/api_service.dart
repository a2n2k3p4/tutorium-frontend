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
      "$baseUrl/classes/search",
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

    if (minPrice != null) queryParams["min_price"] = minPrice.toString();
    if (maxPrice != null) queryParams["max_price"] = maxPrice.toString();
    if (minRating != null) queryParams["min_rating"] = minRating.toString();
    if (maxRating != null) queryParams["max_rating"] = maxRating.toString();
    if (search != null && search.isNotEmpty) queryParams["search"] = search;

    var uri = Uri.parse(
      "$baseUrl/classes",
    ).replace(queryParameters: queryParams);

    // Append multiple categories
    if (categories != null && categories.isNotEmpty) {
      final categoryParams = categories.map((c) => "category=$c").join("&");
      final separator = uri.query.isEmpty ? "?" : "&";
      uri = Uri.parse(uri.toString() + separator + categoryParams);
    }

    print("Filter request: $uri");

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to filter classes (${response.statusCode})");
    }
  }
}
