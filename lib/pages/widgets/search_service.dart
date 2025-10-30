import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SearchService {
  SearchService();

  final String baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

  static const Duration _cacheTtl = Duration(minutes: 5);
  static final Map<String, List<dynamic>> _listCache = {};
  static final Map<String, DateTime> _listCacheTimestamp = {};
  static final Map<String, Future<List<dynamic>>> _inFlight = {};

  Future<List<dynamic>> _getOrFetch(
    String cacheKey,
    Future<List<dynamic>> Function() loader, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cached = _listCache[cacheKey];
    final cachedAt = _listCacheTimestamp[cacheKey];

    final isCacheValid =
        cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) <= _cacheTtl;
    if (!forceRefresh && isCacheValid) {
      return List<dynamic>.from(cached);
    }

    final existingRequest = _inFlight[cacheKey];
    if (existingRequest != null) {
      return List<dynamic>.from(await existingRequest);
    }

    final future = loader()
        .then((value) {
          final copy = List<dynamic>.from(value);
          _listCache[cacheKey] = copy;
          _listCacheTimestamp[cacheKey] = DateTime.now();
          return copy;
        })
        .catchError((error, stackTrace) {
          debugPrint('SearchService error for $cacheKey: $error');
          throw error;
        })
        .whenComplete(() {
          _inFlight.remove(cacheKey);
        });

    _inFlight[cacheKey] = future;

    final result = await future;
    return List<dynamic>.from(result);
  }

  Future<List<dynamic>> getAllClasses({bool forceRefresh = false}) async {
    return _getOrFetch('classes_all', () async {
      try {
        final url = Uri.parse("$baseUrl/classes");
        final response = await http.get(url);

        if (response.statusCode == 200) {
          return json.decode(response.body) as List<dynamic>;
        }

        return <dynamic>[];
      } catch (e) {
        debugPrint('Error fetching classes: $e');
        return <dynamic>[];
      }
    }, forceRefresh: forceRefresh);
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
      final queryParamsAll = <String, List<String>>{};
      if (categories != null && categories.isNotEmpty) {
        final filteredCategories = categories
            .where((c) => c != "All")
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (filteredCategories.isNotEmpty) {
          queryParamsAll["category"] = filteredCategories;
        }
      }

      if (minRating != null) {
        queryParamsAll["min_rating"] = [minRating.toString()];
      }
      if (maxRating != null) {
        queryParamsAll["max_rating"] = [maxRating.toString()];
      }

      final baseUri = Uri.parse("$baseUrl/classes");
      final querySegments = <String>[];
      queryParamsAll.forEach((key, values) {
        for (final value in values) {
          querySegments.add(
            '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
          );
        }
      });
      final queryString = querySegments.join('&');
      final uri = queryString.isEmpty
          ? baseUri
          : Uri.parse('${baseUri.toString()}?$queryString');
      debugPrint("Filter request: $uri");

      final response = await http.get(uri);
      debugPrint("Response status: ${response.statusCode}");

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
      debugPrint("Error filtering classes: $e");
      return [];
    }
  }

  Future<List<dynamic>> getPopularClasses({
    int? limit,
    bool forceRefresh = false,
  }) async {
    final cacheKey = limit != null ? 'popular_$limit' : 'popular_all';
    return _getOrFetch(cacheKey, () async {
      try {
        final uri = Uri.parse(
          "$baseUrl/classes",
        ).replace(queryParameters: {"sort": "popular"});

        debugPrint("Popular classes request: $uri");

        final response = await http.get(uri);
        debugPrint("Popular classes status: ${response.statusCode}");

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

        return <dynamic>[];
      } catch (e) {
        debugPrint("Error fetching popular classes: $e");
        return <dynamic>[];
      }
    }, forceRefresh: forceRefresh);
  }
}
