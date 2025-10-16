import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

int user_id =
    4; // 6 = ถ้าอยากโชว์ตอน Enroll เงินพอ, 4 = ถ้าอยากโชว์ตอน Enroll เงินไม่พอ

class ClassInfo {
  final int id;
  final String name;
  final String teacherName;
  final int teacher_id;
  final String description;
  final double rating;
  final List<String> categories;

  ClassInfo({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.teacher_id,
    required this.description,
    required this.rating,
    required this.categories,
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
      teacher_id: json["teacher_id"] ?? 1,
      description: json["class_description"] ?? "",
      rating: (json["rating"] is num)
          ? (json["rating"] as num).toDouble()
          : 0.0,
      categories: categoryNames,
    );
  }
  String get categoryDisplay =>
      categories.isEmpty ? "General" : categories.join(", ");
}

class ClassSession {
  final int id;
  final int classId;
  final String description;
  final String teacherName;
  final String categories;
  final double price;
  final int learnerLimit;
  final DateTime enrollmentDeadline;
  final DateTime classStart;
  final DateTime classFinish;
  final String status;
  final ClassInfo? classInfo;

  ClassSession({
    required this.id,
    required this.classId,
    required this.description,
    required this.teacherName,
    required this.categories,
    required this.price,
    required this.learnerLimit,
    required this.enrollmentDeadline,
    required this.classStart,
    required this.classFinish,
    required this.status,
    this.classInfo,
  });

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      id: json["ID"] ?? json["id"] ?? 0,
      classId: json["class_id"] ?? 0,
      description: json["description"] ?? "",
      teacherName: json["teacherName"] ?? "",
      categories: json["Class"]["Categories"] ?? "",
      price: (json["price"] as num).toDouble(),
      learnerLimit: json["learner_limit"],
      enrollmentDeadline: DateTime.parse(json["enrollment_deadline"]),
      classStart: DateTime.parse(json["class_start"]),
      classFinish: DateTime.parse(json["class_finish"]),
      status: json["class_status"] ?? "",
      classInfo: json["Class"] != null
          ? ClassInfo.fromJson({
              ...json["Class"],
              "category": json["Class"]["Categories"],
            })
          : null,
    );
  }
}

class UserInfo {
  final int id;
  final String? studentId;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? phoneNumber;
  final int balance;
  final int banCount;

  UserInfo({
    required this.id,
    this.studentId,
    this.firstName,
    this.lastName,
    this.gender,
    this.phoneNumber,
    required this.balance,
    required this.banCount,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['ID'],
      studentId: json['student_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      gender: json['gender'],
      phoneNumber: json['phone_number'],
      balance: json['balance'] ?? 0,
      banCount: json['ban_count'] ?? 0,
    );
  }
}

class ClassSessionService {
  final String baseUrl = '${dotenv.env["API_URL"]}:${dotenv.env["PORT"]}';

  Future<List<ClassSession>> fetchClassSessions(int classId) async {
    final url = Uri.parse("$baseUrl/class_sessions/$classId");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data is List) {
        return data.map((e) => ClassSession.fromJson(e)).toList();
      } else if (data is Map<String, dynamic>) {
        return [ClassSession.fromJson(data)];
      } else {
        throw Exception("Unexpected response format");
      }
    } else {
      throw Exception("Failed to load sessions for class $classId");
    }
  }

  Future<ClassInfo> fetchClassInfo(int classId) async {
    final url = Uri.parse("$baseUrl/classes/$classId");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return ClassInfo.fromJson(jsonData);
    } else {
      throw Exception("Failed to load class $classId");
    }
  }

  Future<UserInfo> fetchUser() async {
    final url = Uri.parse("$baseUrl/users/$user_id");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return UserInfo.fromJson(jsonData);
    } else {
      throw Exception("Failed to load user");
    }
  }

  Future<UserInfo> fetchUserById(int id) async {
    final url = Uri.parse("$baseUrl/users/$id");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return UserInfo.fromJson(jsonData);
    } else {
      throw Exception("Failed to load user $id");
    }
  }
}
