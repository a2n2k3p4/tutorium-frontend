import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/models/class_models.dart' as models;
import 'package:tutorium_frontend/util/local_storage.dart';

class ClassInfo {
  final int id;
  final String name;
  final String teacherName;
  final int teacherId;
  final String description;
  final double rating;
  final List<String> categories;
  final String? bannerPicture;

  ClassInfo({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.teacherId,
    required this.description,
    required this.rating,
    required this.categories,
    this.bannerPicture,
  });

  factory ClassInfo.fromJson(Map<String, dynamic> json) {
    final List<String> categoryNames =
        (json['Categories'] as List?)
            ?.map((c) => c['class_category']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];
    return ClassInfo(
      id: json["ID"] ?? json["id"] ?? 0,
      name: json["class_name"] ?? "",
      teacherName: json["teacherName"] ?? "",
      teacherId: json["teacher_id"] ?? 1,
      description: json["class_description"] ?? "",
      rating: (json["rating"] is num)
          ? (json["rating"] as num).toDouble()
          : 0.0,
      categories: categoryNames,
      bannerPicture: json["banner_picture"] ?? json["banner_picture_url"],
    );
  }

  String get categoryDisplay =>
      categories.isEmpty ? "General" : categories.join(", ");
}

class UserInfo {
  final int id;
  final String? studentId;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? phoneNumber;
  final double balance;
  final int banCount;
  final int? learnerId;

  UserInfo({
    required this.id,
    this.studentId,
    this.firstName,
    this.lastName,
    this.gender,
    this.phoneNumber,
    required this.balance,
    required this.banCount,
    this.learnerId,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final learner = json['Learner'] as Map<String, dynamic>?;
    return UserInfo(
      id: _parseInt(json['ID']) ?? _parseInt(json['id']) ?? 0,
      studentId: json['student_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      gender: json['gender'],
      phoneNumber: json['phone_number'],
      balance: _parseBalance(json['balance']),
      banCount: json['ban_count'] ?? 0,
      learnerId: learner != null
          ? _parseInt(learner['ID']) ?? _parseInt(learner['id'])
          : null,
    );
  }

  UserInfo copyWith({
    int? id,
    String? studentId,
    String? firstName,
    String? lastName,
    String? gender,
    String? phoneNumber,
    double? balance,
    int? banCount,
    int? learnerId,
  }) {
    return UserInfo(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      banCount: banCount ?? this.banCount,
      learnerId: learnerId ?? this.learnerId,
    );
  }
}

class ClassSessionService {
  static const Duration _requestTimeout = Duration(seconds: 12);

  String get _baseUrl => _resolveBaseUrl();

  static Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final token = await LocalStorage.getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<models.ClassSession>> fetchClassSessions(int classId) async {
    final url = Uri.parse(
      '$_baseUrl/class_sessions',
    ).replace(queryParameters: {'class_id': classId.toString()});
    final headers = await _authHeaders();
    final response = await _sendWithTimeout(
      () => http.get(url, headers: headers.isEmpty ? null : headers),
      url,
      'GET',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final sessions = _decodeSessionsPayload(data);
      return sessions
          .where((session) => session.classId == classId)
          .toList(growable: false);
    } else {
      throw Exception('Failed to load sessions for class $classId');
    }
  }

  Future<ClassInfo> fetchClassInfo(int classId) async {
    final url = Uri.parse('$_baseUrl/classes/$classId');
    final response = await _sendWithTimeout(() => http.get(url), url, 'GET');

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return ClassInfo.fromJson(jsonData);
    } else {
      throw Exception('Failed to load class $classId');
    }
  }

  Future<UserInfo> fetchUser() async {
    final userId = await LocalStorage.getUserId();
    if (userId == null) {
      throw Exception('User ID is not available in local storage');
    }
    return fetchUserById(userId);
  }

  Future<UserInfo> fetchUserById(int id) async {
    final url = Uri.parse('$_baseUrl/users/$id');
    final headers = await _authHeaders();
    final response = await _sendWithTimeout(
      () => http.get(url, headers: headers.isEmpty ? null : headers),
      url,
      'GET',
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return UserInfo.fromJson(jsonData);
    } else {
      throw Exception('Failed to load user $id');
    }
  }

  static Future<List<models.ClassSession>> getSessionsByClass(
    int classId,
  ) async {
    return ClassSessionService().fetchClassSessions(classId);
  }

  /// Fetch sessions for multiple classes at once (batch)
  static Future<Map<int, List<models.ClassSession>>> getSessionsByClasses(
    List<int> classIds,
  ) async {
    if (classIds.isEmpty) return {};

    // Request all sessions for multiple classes in ONE request
    final url = Uri.parse('${_resolveBaseUrl()}/class_sessions').replace(
      queryParameters: {
        'class_ids': classIds.join(','), // e.g., "1,2,3,4"
      },
    );
    final headers = await _authHeaders();

    final response = await _sendWithTimeout(
      () => http.get(url, headers: headers.isEmpty ? null : headers),
      url,
      'GET',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final allSessions = _decodeSessionsPayload(data);

      // Group sessions by class_id
      final grouped = <int, List<models.ClassSession>>{};
      for (final classId in classIds) {
        grouped[classId] = [];
      }

      for (final session in allSessions) {
        if (grouped.containsKey(session.classId)) {
          grouped[session.classId]!.add(session);
        }
      }

      return grouped;
    } else {
      throw Exception('Failed to load sessions for classes: $classIds');
    }
  }

  /// Fetch enrollments for multiple sessions at once (batch)
  static Future<Map<int, List<Map<String, dynamic>>>> getEnrollmentsBySessions(
    List<int> sessionIds,
  ) async {
    if (sessionIds.isEmpty) return {};

    // Request all enrollments for multiple sessions in ONE request
    final url = Uri.parse('${_resolveBaseUrl()}/enrollments').replace(
      queryParameters: {
        'session_ids': sessionIds.join(','), // e.g., "1,2,3,4"
        'include': 'learner,user',
      },
    );
    final headers = await _authHeaders();

    final response = await _sendWithTimeout(
      () => http.get(url, headers: headers.isEmpty ? null : headers),
      url,
      'GET',
    );

    if (response.statusCode == 200) {
      final List<dynamic> allEnrollments = json.decode(response.body);

      // Group enrollments by class_session_id
      final grouped = <int, List<Map<String, dynamic>>>{};
      for (final sessionId in sessionIds) {
        grouped[sessionId] = [];
      }

      for (final enrollment in allEnrollments) {
        if (enrollment is! Map<String, dynamic>) continue;

        final sessionId = enrollment['class_session_id'];
        if (sessionId != null && grouped.containsKey(sessionId)) {
          grouped[sessionId]!.add(enrollment);
        }
      }

      return grouped;
    } else {
      throw Exception('Failed to load enrollments for sessions: $sessionIds');
    }
  }

  static Future<List<Map<String, dynamic>>> getEnrollmentsBySession(
    int sessionId,
  ) async {
    // Request with ?include=learner,user to get all data in ONE request
    final url = Uri.parse('${_resolveBaseUrl()}/enrollments').replace(
      queryParameters: {
        'class_session_id': sessionId.toString(),
        'include': 'learner,user', // Ask backend to include related data
      },
    );
    final headers = await _authHeaders();

    final response = await _sendWithTimeout(
      () => http.get(url, headers: headers.isEmpty ? null : headers),
      url,
      'GET',
    );

    if (response.statusCode == 200) {
      final List<dynamic> enrollments = json.decode(response.body);

      // Backend should return enrollments with learner and user already populated
      // No need for N+1 queries!
      return enrollments.whereType<Map<String, dynamic>>().toList();
    } else {
      throw Exception('Failed to load enrollments for session $sessionId');
    }
  }

  static Future<Map<String, dynamic>> createSession(
    Map<String, dynamic> sessionData,
  ) async {
    final url = Uri.parse('${_resolveBaseUrl()}/class_sessions');

    final requestBody = json.encode(sessionData);
    debugPrint('�� Sending POST to: $url');
    debugPrint('📤 Request body: $requestBody');

    final headers = await _authHeaders(json: true);

    final response = await _sendWithTimeout(
      () => http.post(
        url,
        headers: headers.isEmpty
            ? {'Content-Type': 'application/json'}
            : headers,
        body: requestBody,
      ),
      url,
      'POST',
    );

    debugPrint('📥 Response status: ${response.statusCode}');
    debugPrint('📥 Response body: ${response.body}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      // Parse error message from response if available
      String errorMsg = 'Failed to create session';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map<String, dynamic>) {
          errorMsg = errorData['error'] ?? errorData['message'] ?? errorMsg;
        }
      } catch (e) {
        errorMsg = response.body;
      }
      throw Exception(
        'Failed to create session (${response.statusCode}): $errorMsg',
      );
    }
  }

  /// Delete an enrollment from a session
  static Future<void> deleteEnrollment(
    int sessionId,
    dynamic enrollmentId,
  ) async {
    final url = Uri.parse('${_resolveBaseUrl()}/enrollments/$enrollmentId');

    debugPrint('📤 Sending DELETE to: $url');

    final headers = await _authHeaders();

    final response = await _sendWithTimeout(
      () => http.delete(url, headers: headers.isEmpty ? null : headers),
      url,
      'DELETE',
    );

    debugPrint('📥 Response status: ${response.statusCode}');
    debugPrint('📥 Response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      // Successfully deleted
      return;
    } else {
      // Parse error message from response if available
      String errorMsg = 'Failed to delete enrollment';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map<String, dynamic>) {
          errorMsg = errorData['error'] ?? errorData['message'] ?? errorMsg;
        }
      } catch (e) {
        errorMsg = response.body;
      }
      throw Exception(
        'Failed to delete enrollment (${response.statusCode}): $errorMsg',
      );
    }
  }

  static String _resolveBaseUrl() {
    final apiUrl = dotenv.env['API_URL'] ?? '';
    final port = dotenv.env['PORT'];
    if (port != null && port.isNotEmpty) {
      return '$apiUrl:$port';
    }
    return apiUrl;
  }

  static Future<http.Response> _sendWithTimeout(
    Future<http.Response> Function() request,
    Uri url,
    String method,
  ) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        'Request timed out after ${_requestTimeout.inSeconds}s ($method ${url.path}).',
      );
    } on SocketException catch (e) {
      throw Exception('Network error: ${_formatNetworkError(e.message)}');
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${_formatNetworkError(e.message)}');
    }
  }

  static String _formatNetworkError(String? message) {
    if (message == null) return 'Unable to reach the server';
    final trimmed = message.trim();
    return trimmed.isEmpty ? 'Unable to reach the server' : trimmed;
  }

  static models.ClassSession _mapToModel(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid session payload');
    }
    final normalized = _normalizeSessionJson(raw);
    return models.ClassSession.fromJson(normalized);
  }

  static Map<String, dynamic> _normalizeSessionJson(Map<String, dynamic> json) {
    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key) && json[key] != null) {
          return json[key];
        }
      }
      return null;
    }

    String? toDateString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is DateTime) return value.toIso8601String();
      return value.toString();
    }

    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final classStart = toDateString(
      pick(['class_start', 'classStart', 'ClassStart']),
    );
    final classFinish = toDateString(
      pick(['class_finish', 'classFinish', 'ClassFinish']),
    );
    final enrollmentDeadline = toDateString(
      pick(['enrollment_deadline', 'enrollmentDeadline', 'EnrollmentDeadline']),
    );

    if (classStart == null ||
        classFinish == null ||
        enrollmentDeadline == null) {
      throw Exception('Session payload missing schedule information');
    }

    return {
      'id': toInt(pick(['id', 'ID'])) ?? 0,
      'class_id': toInt(pick(['class_id', 'classId', 'ClassID'])) ?? 0,
      'class_start': classStart,
      'class_finish': classFinish,
      'enrollment_deadline': enrollmentDeadline,
      'class_status':
          (pick(['class_status', 'status', 'classStatus']) ?? 'scheduled')
              .toString(),
      'description': (pick(['description', 'class_description']) ?? '')
          .toString(),
      'learner_limit': toInt(pick(['learner_limit', 'learnerLimit'])) ?? 0,
      'price': toDouble(pick(['price'])) ?? 0.0,
      'class_url': pick([
        'class_url',
        'classUrl',
        'meeting_url',
        'meetingUrl',
        'MeetingUrl',
      ]),
    };
  }

  static List<models.ClassSession> _decodeSessionsPayload(dynamic data) {
    if (data is List) {
      return data
          .map((session) => _mapToModel(session))
          .toList(growable: false);
    } else if (data is Map<String, dynamic>) {
      return [_mapToModel(data)];
    } else {
      throw Exception('Unexpected response format');
    }
  }
}

double _parseBalance(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

int? _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
