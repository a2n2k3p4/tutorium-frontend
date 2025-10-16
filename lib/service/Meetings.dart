import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class MeetingLinkResponse {
  final Map<String, dynamic> data;

  MeetingLinkResponse({required this.data});

  factory MeetingLinkResponse.fromJson(Map<String, dynamic> json) {
    return MeetingLinkResponse(data: json);
  }
}

class MeetingService {
  /// GET /meetings/{id} (200, 400, 401, 404, 500)
  static Future<MeetingLinkResponse> fetchByClassSessionId(
    int classSessionId,
  ) async {
    final res = await http.get(
      ApiService.endpoint("/meetings/$classSessionId"),
    );
    switch (res.statusCode) {
      case 200:
        return MeetingLinkResponse.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid class session ID: ${res.body}");
      case 401:
        throw Exception("Unauthorized: ${res.body}");
      case 404:
        throw Exception(
          "Class session not found or meeting not created: ${res.body}",
        );
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to fetch meeting link (code: ${res.statusCode})",
        );
    }
  }
}
