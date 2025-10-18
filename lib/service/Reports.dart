import 'package:tutorium_frontend/service/api_client.dart';

class Report {
  final int? id;
  final int classSessionId;
  final DateTime reportDate;
  final String reportDescription;
  final String? reportPicture;
  final String reportReason;
  final String? reportResult;
  final String reportStatus;
  final String reportType;
  final int reportUserId;
  final int reportedUserId;

  const Report({
    this.id,
    required this.classSessionId,
    required this.reportDate,
    required this.reportDescription,
    this.reportPicture,
    required this.reportReason,
    this.reportResult,
    required this.reportStatus,
    required this.reportType,
    required this.reportUserId,
    required this.reportedUserId,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] ?? json['ID'],
      classSessionId: json['class_session_id'] ?? 0,
      reportDate: DateTime.parse(json['report_date']).toUtc(),
      reportDescription: json['report_description'] ?? '',
      reportPicture: json['report_picture'],
      reportReason: json['report_reason'] ?? '',
      reportResult: json['report_result'],
      reportStatus: json['report_status'] ?? '',
      reportType: json['report_type'] ?? '',
      reportUserId: json['report_user_id'] ?? 0,
      reportedUserId: json['reported_user_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'class_session_id': classSessionId,
      'report_date': reportDate.toIso8601String(),
      'report_description': reportDescription,
      if (reportPicture != null) 'report_picture': reportPicture,
      'report_reason': reportReason,
      if (reportResult != null) 'report_result': reportResult,
      'report_status': reportStatus,
      'report_type': reportType,
      'report_user_id': reportUserId,
      'reported_user_id': reportedUserId,
    };
  }

  static final ApiClient _client = ApiClient();

  static Future<List<Report>> fetchAll({Map<String, dynamic>? query}) async {
    final response = await _client.getJsonList(
      '/reports',
      queryParameters: query,
    );
    return response.map(Report.fromJson).toList();
  }

  static Future<Report> fetchById(int id) async {
    final response = await _client.getJsonMap('/reports/$id');
    return Report.fromJson(response);
  }

  static Future<Report> create(Report report) async {
    final response = await _client.postJsonMap(
      '/reports',
      body: report.toJson(),
    );
    return Report.fromJson(response);
  }

  static Future<Report> update(int id, Report report) async {
    final response = await _client.putJsonMap(
      '/reports/$id',
      body: report.toJson(),
    );
    return Report.fromJson(response);
  }

  static Future<void> delete(int id) async {
    await _client.delete('/reports/$id');
  }
}
