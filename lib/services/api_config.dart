import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Build base URL from .env (fallback to defaults if missing)
  static String get baseUrl {
    final host = dotenv.env['API_URL']?.trim();
    final port = dotenv.env['PORT']?.trim();
    final resolvedHost = (host == null || host.isEmpty) ? '65.108.156.197' : host;
    final resolvedPort = (port == null || port.isEmpty) ? '8000' : port;
    return 'http://$resolvedHost:$resolvedPort';
  }

  // Endpoints
  static const String login = '/login';
  static const String admins = '/admins';
  static const String banLearners = '/banlearners';
  static const String banTeachers = '/banteachers';
  static const String classCategories = '/class_categories';
  static const String classSessions = '/class_sessions';
  static const String classes = '/classes';
  static const String enrollments = '/enrollments';
  static const String learners = '/learners';
  static const String notifications = '/notifications';
  static const String payments = '/payments';
  static const String reports = '/reports';
  static const String reviews = '/reviews';
  static const String teachers = '/teachers';
  static const String users = '/users';
  static const String health = '/health';
  static const String webhooks = '/webhooks';
}
