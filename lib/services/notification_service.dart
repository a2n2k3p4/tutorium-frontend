import '../models/other_models.dart';
import '../services/api_config.dart';
import '../services/base_api_service.dart';

class NotificationService extends BaseApiService {
  // Get all notifications
  Future<List<NotificationModel>> getNotifications() async {
    final response = await get(ApiConfig.notifications);
    final data = handleListResponse(response);
    return data.map((json) => NotificationModel.fromJson(json)).toList();
  }

  // Get notification by ID
  Future<NotificationModel> getNotificationById(int id) async {
    final response = await get('${ApiConfig.notifications}/$id');
    final data = handleResponse(response);
    return NotificationModel.fromJson(data);
  }

  // Create new notification
  Future<NotificationModel> createNotification(
    NotificationModel notification,
  ) async {
    final response = await post(ApiConfig.notifications, notification.toJson());
    final data = handleResponse(response);
    return NotificationModel.fromJson(data);
  }

  // Update notification
  Future<NotificationModel> updateNotification(
    int id,
    NotificationModel notification,
  ) async {
    final response = await put(
      '${ApiConfig.notifications}/$id',
      notification.toJson(),
    );
    final data = handleResponse(response);
    return NotificationModel.fromJson(data);
  }

  // Delete notification
  Future<void> deleteNotification(int id) async {
    await delete('${ApiConfig.notifications}/$id');
  }
}

class ReportService extends BaseApiService {
  // Get all reports
  Future<List<Report>> getReports() async {
    final response = await get(ApiConfig.reports);
    final data = handleListResponse(response);
    return data.map((json) => Report.fromJson(json)).toList();
  }

  // Get report by ID
  Future<Report> getReportById(int id) async {
    final response = await get('${ApiConfig.reports}/$id');
    final data = handleResponse(response);
    return Report.fromJson(data);
  }

  // Create new report
  Future<Report> createReport(Report report) async {
    final response = await post(ApiConfig.reports, report.toJson());
    final data = handleResponse(response);
    return Report.fromJson(data);
  }

  // Update report
  Future<Report> updateReport(int id, Report report) async {
    final response = await put('${ApiConfig.reports}/$id', report.toJson());
    final data = handleResponse(response);
    return Report.fromJson(data);
  }

  // Delete report
  Future<void> deleteReport(int id) async {
    await delete('${ApiConfig.reports}/$id');
  }
}
