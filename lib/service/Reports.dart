import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tutorium_frontend/service/Apiservice.dart';

class Report {
  final int classSessionId;
  final String reportDate;
  final String reportDescription;
  final String reportPicture;
  final String reportReason;
  final String reportResult;
  final String reportStatus;
  final String reportType;
  final int reportUserId;
  final int reportedUserId;

  Report({
    required this.classSessionId,
    required this.reportDate,
    required this.reportDescription,
    required this.reportPicture,
    required this.reportReason,
    required this.reportResult,
    required this.reportStatus,
    required this.reportType,
    required this.reportUserId,
    required this.reportedUserId,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      classSessionId: json['class_session_id'],
      reportDate: json['report_date'],
      reportDescription: json['report_description'],
      reportPicture: json['report_picture'],
      reportReason: json['report_reason'],
      reportResult: json['report_result'],
      reportStatus: json['report_status'],
      reportType: json['report_type'],
      reportUserId: json['report_user_id'],
      reportedUserId: json['reported_user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_session_id': classSessionId,
      'report_date': reportDate,
      'report_description': reportDescription,
      'report_picture': reportPicture,
      'report_reason': reportReason,
      'report_result': reportResult,
      'report_status': reportStatus,
      'report_type': reportType,
      'report_user_id': reportUserId,
      'reported_user_id': reportedUserId,
    };
  }

  // ---------- CRUD ----------

  /// GET /reports (200, 500)
  static Future<List<Report>> fetchAll() async {
    final res = await http.get(ApiService.endpoint("/reports"));
    switch (res.statusCode) {
      case 200:
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Report.fromJson(e)).toList();
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch reports (code: ${res.statusCode})");
    }
  }

  /// GET /reports/:id (200, 400, 404, 500)
  static Future<Report> fetchById(int id) async {
    final res = await http.get(ApiService.endpoint("/reports/$id"));
    switch (res.statusCode) {
      case 200:
        return Report.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Report not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to fetch report $id (code: ${res.statusCode})");
    }
  }

  /// POST /reports (201, 400, 500)
  static Future<Report> create(Report report) async {
    final res = await http.post(
      ApiService.endpoint("/reports"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(report.toJson()),
    );
    switch (res.statusCode) {
      case 201:
        return Report.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception("Failed to create report (code: ${res.statusCode})");
    }
  }

  /// PUT /reports/:id (200, 400, 404, 500)
  static Future<Report> update(int id, Report report) async {
    final res = await http.put(
      ApiService.endpoint("/reports/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(report.toJson()),
    );
    switch (res.statusCode) {
      case 200:
        return Report.fromJson(jsonDecode(res.body));
      case 400:
        throw Exception("Invalid input: ${res.body}");
      case 404:
        throw Exception("Report not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to update report $id (code: ${res.statusCode})",
        );
    }
  }

  /// DELETE /reports/:id (200, 400, 404, 500)
  static Future<void> delete(int id) async {
    final res = await http.delete(ApiService.endpoint("/reports/$id"));
    switch (res.statusCode) {
      case 200:
        return;
      case 400:
        throw Exception("Invalid ID: ${res.body}");
      case 404:
        throw Exception("Report not found");
      case 500:
        throw Exception("Server error: ${res.body}");
      default:
        throw Exception(
          "Failed to delete report $id (code: ${res.statusCode})",
        );
    }
  }
}
