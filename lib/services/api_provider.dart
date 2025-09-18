// API Service Provider - ใช้สำหรับ dependency injection
import '../services/services.dart';

class ApiServiceProvider {
  static final ApiServiceProvider _instance = ApiServiceProvider._internal();

  factory ApiServiceProvider() => _instance;

  ApiServiceProvider._internal();

  // Singleton services
  final AuthService auth = AuthService();
  final UserService user = UserService();
  final TeacherService teacher = TeacherService();
  final LearnerService learner = LearnerService();
  final ClassService classService = ClassService();
  final ClassCategoryService classCategory = ClassCategoryService();
  final ClassSessionService classSession = ClassSessionService();
  final EnrollmentService enrollment = EnrollmentService();
  final ReviewService review = ReviewService();
  final NotificationService notification = NotificationService();
  final PaymentService payment = PaymentService();
  final AdminService admin = AdminService();
  final BanService ban = BanService();
  final ReportService report = ReportService();
}

// Helper class สำหรับการใช้งานง่ายๆ
class API {
  static final ApiServiceProvider _provider = ApiServiceProvider();

  static AuthService get auth => _provider.auth;

  static UserService get user => _provider.user;

  static TeacherService get teacher => _provider.teacher;

  static LearnerService get learner => _provider.learner;

  static ClassService get classService => _provider.classService;

  static ClassCategoryService get classCategory => _provider.classCategory;

  static ClassSessionService get classSession => _provider.classSession;

  static EnrollmentService get enrollment => _provider.enrollment;

  static ReviewService get review => _provider.review;

  static NotificationService get notification => _provider.notification;

  static PaymentService get payment => _provider.payment;

  static AdminService get admin => _provider.admin;

  static BanService get ban => _provider.ban;

  static ReportService get report => _provider.report;
}
