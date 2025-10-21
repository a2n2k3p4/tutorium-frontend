import 'package:tutorium_frontend/service/api_client.dart';
import 'package:tutorium_frontend/service/enrollments.dart';
import 'package:tutorium_frontend/service/money_transaction_service.dart';
import 'package:tutorium_frontend/service/class_sessions.dart';

/// Enhanced enrollment service that handles payment automatically
class EnrollmentWithPaymentService {
  /// Enroll in a class session with automatic payment to teacher
  /// Returns the enrollment if successful, throws exception otherwise
  static Future<Enrollment> enrollWithPayment({
    required int learnerId,
    required int learnerUserId,
    required int classSessionId,
  }) async {
    Enrollment? createdEnrollment;
    MoneyTransaction? transaction;
    bool enrollmentCreated = false;

    try {
      // Step 1: Verify class session exists and get details
      final session = await ClassSession.fetchById(classSessionId);
      final price = session.price;

      if (price < 0) {
        throw Exception('Invalid class price');
      }

      // Step 2: Check if already enrolled
      final existingEnrollments = await Enrollment.fetchAll(
        query: {'learner_id': learnerId, 'class_session_id': classSessionId},
      );

      if (existingEnrollments.isNotEmpty) {
        throw Exception('Already enrolled in this class session');
      }

      // Step 3: Check if class is full (max 20 people per session)
      final allEnrollments = await Enrollment.fetchAll();
      final activeEnrollments = allEnrollments
          .where(
            (e) =>
                e.classSessionId == classSessionId &&
                e.enrollmentStatus == 'active',
          )
          .length;

      // Enforce maximum of 20 participants per session
      const maxParticipants = 20;
      final effectiveLimit = session.learnerLimit > maxParticipants
          ? maxParticipants
          : session.learnerLimit;

      if (activeEnrollments >= effectiveLimit) {
        throw Exception(
          'Class session is full (maximum $effectiveLimit participants)',
        );
      }

      // Step 4: Create enrollment first
      final enrollment = Enrollment(
        classSessionId: classSessionId,
        enrollmentStatus: 'pending', // Will change to active after payment
        learnerId: learnerId,
      );

      createdEnrollment = await Enrollment.create(enrollment);
      enrollmentCreated = true;

      // Step 5: Process payment - transfer money to teacher
      if (price > 0) {
        transaction = await MoneyTransactionService.enrollAndTransferMoney(
          learnerId: learnerId,
          learnerUserId: learnerUserId,
          classSessionId: classSessionId,
          enrollmentId: createdEnrollment.classSessionId,
        );
      }

      // Step 6: Update enrollment status to active
      final activeEnrollment = Enrollment(
        classSessionId: classSessionId,
        enrollmentStatus: 'active',
        learnerId: learnerId,
      );

      final updatedEnrollment = await Enrollment.update(
        createdEnrollment.classSessionId,
        activeEnrollment,
      );

      return updatedEnrollment;
    } catch (e) {
      // Rollback on error
      if (enrollmentCreated && createdEnrollment != null) {
        try {
          // Try to delete the enrollment
          await Enrollment.delete(createdEnrollment.classSessionId);
        } catch (_) {
          // Log rollback failure but don't throw
        }

        // Try to rollback payment if it was made
        if (transaction != null) {
          try {
            await MoneyTransactionService.rollbackTransaction(transaction);
          } catch (_) {
            // Log rollback failure but don't throw
          }
        }
      }

      // Rethrow the original error with better message
      if (e is ApiException) {
        throw Exception('Enrollment failed: ${e.body ?? e.statusCode}');
      }
      throw Exception('Enrollment failed: ${e.toString()}');
    }
  }

  /// Cancel enrollment with automatic 100% refund to learner
  /// DISABLED: Enrollment cancellation is not allowed once enrolled
  static Future<void> cancelWithRefund({
    required int enrollmentId,
    required int learnerUserId,
    required int classSessionId,
  }) async {
    // Enrollment cancellation is disabled - learners cannot cancel once enrolled
    throw Exception(
      'ไม่สามารถยกเลิกการลงทะเบียนได้ เนื่องจากคุณได้ลงทะเบียนแล้ว',
    );
  }

  /// Get enrollment with payment details
  static Future<EnrollmentWithPaymentInfo> getEnrollmentWithPayment({
    required int enrollmentId,
    required int userId,
  }) async {
    try {
      final enrollment = await Enrollment.fetchById(enrollmentId);
      final session = await ClassSession.fetchById(enrollment.classSessionId);

      // Get transaction history for this enrollment
      final transactions = await MoneyTransactionService.getTransactionHistory(
        userId: userId,
      );

      final enrollmentTransactions = transactions
          .where((t) => t.enrollmentId == enrollmentId)
          .toList();

      return EnrollmentWithPaymentInfo(
        enrollment: enrollment,
        session: session,
        transactions: enrollmentTransactions,
        totalPaid: enrollmentTransactions
            .where((t) => t.type == TransactionType.enrollment)
            .fold(0.0, (sum, t) => sum + t.amount),
        totalRefunded: enrollmentTransactions
            .where((t) => t.type == TransactionType.refund)
            .fold(0.0, (sum, t) => sum + t.amount),
      );
    } catch (e) {
      throw Exception('Failed to get enrollment info: ${e.toString()}');
    }
  }

  /// Check if learner can afford to enroll in a class
  static Future<bool> canAffordClass({
    required int learnerUserId,
    required int classSessionId,
  }) async {
    try {
      final session = await ClassSession.fetchById(classSessionId);
      final user = await ApiClient().getJsonMap('/users/$learnerUserId');
      final balance = _parseDouble(user['balance']);

      return balance >= session.price;
    } catch (_) {
      return false;
    }
  }

  /// Get required amount for enrollment
  static Future<double> getRequiredAmount(int classSessionId) async {
    final session = await ClassSession.fetchById(classSessionId);
    return session.price;
  }
}

/// Model combining enrollment with payment information
class EnrollmentWithPaymentInfo {
  final Enrollment enrollment;
  final ClassSession session;
  final List<MoneyTransaction> transactions;
  final double totalPaid;
  final double totalRefunded;

  const EnrollmentWithPaymentInfo({
    required this.enrollment,
    required this.session,
    required this.transactions,
    required this.totalPaid,
    required this.totalRefunded,
  });

  double get netAmount => totalPaid - totalRefunded;
  bool get hasRefund => totalRefunded > 0;
  bool get isFullyRefunded => totalRefunded >= totalPaid;
}

double _parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
