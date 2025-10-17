import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class MeetingService {
  /// GET /meetings/{id} (200, 400, 401, 404, 500)
  static Future<MeetingLinkResponse> fetchByClassSessionId(
    int classSessionId, {
    String? token,
  }) async {
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final res = await http.get(
      ApiService.endpoint("/meetings/$classSessionId"),
      headers: headers.isEmpty ? null : headers,
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

class MeetingLinkResponse {
  final Map<String, dynamic> data;

  MeetingLinkResponse({required this.data});

  factory MeetingLinkResponse.fromJson(Map<String, dynamic> json) {
    return MeetingLinkResponse(data: json);
  }

  String? get link {
    if (data.containsKey('meeting_link')) {
      final value = data['meeting_link'];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    if (data.containsKey('meetingUrl')) {
      final value = data['meetingUrl'];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    if (data.containsKey('url')) {
      final value = data['url'];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
