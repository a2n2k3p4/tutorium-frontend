import 'package:tutorium_frontend/service/api_client.dart';

class MeetingLinkResponse {
  final Map<String, dynamic> data;

  const MeetingLinkResponse({required this.data});

  factory MeetingLinkResponse.fromJson(Map<String, dynamic> json) {
    return MeetingLinkResponse(data: json);
  }

  String? get link {
    for (final key in ['meeting_link', 'meetingUrl', 'url']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}

class MeetingService {
  static final ApiClient _client = ApiClient();

  /// GET /meetings/:class_session_id
  static Future<MeetingLinkResponse> fetchByClassSessionId(
    int classSessionId, {
    String? token,
  }) async {
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _client.getJsonMap(
      '/meetings/$classSessionId',
      headers: headers.isEmpty ? null : headers,
    );
    return MeetingLinkResponse.fromJson(response);
  }
}
