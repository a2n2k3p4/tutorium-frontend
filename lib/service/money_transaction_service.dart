import 'package:tutorium_frontend/service/api_client.dart';
import 'package:tutorium_frontend/service/users.dart';
import 'package:tutorium_frontend/service/teachers.dart' as teachers;
import 'package:tutorium_frontend/service/class_sessions.dart';

/// Transaction type for money transfer
enum TransactionType {
  enrollment, // Learner pays for enrollment
  refund, // Refund to learner on cancellation
  teacherPayment, // Payment to teacher
}

/// Transaction record model
class MoneyTransaction {
  final int? id;
  final int fromUserId;
  final int toUserId;
  final double amount;
  final TransactionType type;
  final int? classSessionId;
  final int? enrollmentId;
  final DateTime createdAt;
  final String status; // pending, completed, failed, reversed
  final String? description;

  const MoneyTransaction({
    this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.type,
    this.classSessionId,
    this.enrollmentId,
    required this.createdAt,
    required this.status,
    this.description,
  });

  factory MoneyTransaction.fromJson(Map<String, dynamic> json) {
    return MoneyTransaction(
      id: json['id'],
      fromUserId: json['from_user_id'] ?? 0,
      toUserId: json['to_user_id'] ?? 0,
      amount: _parseDouble(json['amount']),
      type: _parseTransactionType(json['type']),
      classSessionId: json['class_session_id'],
      enrollmentId: json['enrollment_id'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      status: json['status'] ?? 'pending',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount': amount,
      'type': type.name,
      'class_session_id': classSessionId,
      'enrollment_id': enrollmentId,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'description': description,
    };
  }

  static TransactionType _parseTransactionType(String? type) {
    switch (type) {
      case 'enrollment':
        return TransactionType.enrollment;
      case 'refund':
        return TransactionType.refund;
      case 'teacherPayment':
        return TransactionType.teacherPayment;
      default:
        return TransactionType.enrollment;
    }
  }
}

/// Service for handling money transactions between learners and teachers
class MoneyTransactionService {
  static final ApiClient _client = ApiClient();
  static final List<MoneyTransaction> _localTransactions = [];

  /// Transfer money from learner to teacher when enrolling in a class
  /// Returns transaction record or throws exception
  static Future<MoneyTransaction> enrollAndTransferMoney({
    required int learnerId,
    required int learnerUserId,
    required int classSessionId,
    required int? enrollmentId,
  }) async {
    try {
      // 1. Get class session details
      final session = await ClassSession.fetchById(classSessionId);
      final amount = session.price;

      if (amount <= 0) {
        throw Exception('Invalid class price');
      }

      // 2. Get learner's user info to check balance
      final learnerUser = await User.fetchById(learnerUserId);

      if (learnerUser.balance < amount) {
        throw Exception(
          'Insufficient balance. Required: ฿${amount.toStringAsFixed(2)}, '
          'Available: ฿${learnerUser.balance.toStringAsFixed(2)}',
        );
      }

      // 3. Get teacher's user ID
      final classInfo = await _client.getJsonMap('/classes/${session.classId}');
      final teacherId = classInfo['teacher_id'];
      if (teacherId == null) {
        throw Exception('Teacher not found for this class');
      }

      final teacher = await teachers.Teacher.fetchById(teacherId);
      final teacherUserId = teacher.userId;

      // 4. Deduct money from learner
      final newLearnerBalance = learnerUser.balance - amount;
      await User.update(
        learnerUserId,
        learnerUser.copyWith(balance: newLearnerBalance),
      );

      // 5. Add money to teacher (100% of class price)
      final teacherUser = await User.fetchById(teacherUserId);
      final newTeacherBalance = teacherUser.balance + amount;
      await User.update(
        teacherUserId,
        teacherUser.copyWith(balance: newTeacherBalance),
      );

      // 6. Record transaction
      final transaction = MoneyTransaction(
        fromUserId: learnerUserId,
        toUserId: teacherUserId,
        amount: amount,
        type: TransactionType.enrollment,
        classSessionId: classSessionId,
        enrollmentId: enrollmentId,
        createdAt: DateTime.now(),
        status: 'completed',
        description:
            'Enrollment payment for session $classSessionId - ฿${amount.toStringAsFixed(2)} transferred to teacher',
      );

      _localTransactions.add(transaction);

      return transaction;
    } on ApiException catch (e) {
      throw Exception(
        'Payment failed: ${e.body ?? 'Unknown error (${e.statusCode})'}',
      );
    } catch (e) {
      throw Exception('Payment failed: ${e.toString()}');
    }
  }

  /// Refund 100% money to learner when cancelling enrollment
  static Future<MoneyTransaction> cancelAndRefundMoney({
    required int learnerUserId,
    required int classSessionId,
    required int? enrollmentId,
  }) async {
    try {
      // 1. Get class session details
      final session = await ClassSession.fetchById(classSessionId);
      final amount = session.price;

      if (amount <= 0) {
        throw Exception('Invalid class price');
      }

      // 2. Get teacher's user ID
      final classInfo = await _client.getJsonMap('/classes/${session.classId}');
      final teacherId = classInfo['teacher_id'];
      if (teacherId == null) {
        throw Exception('Teacher not found for this class');
      }

      final teacher = await teachers.Teacher.fetchById(teacherId);
      final teacherUserId = teacher.userId;

      // 3. Get current balances
      final learnerUser = await User.fetchById(learnerUserId);
      final teacherUser = await User.fetchById(teacherUserId);

      // 4. Check if teacher has enough balance to refund
      if (teacherUser.balance < amount) {
        throw Exception(
          'Teacher has insufficient balance for refund. '
          'Please contact support.',
        );
      }

      // 5. Deduct money from teacher
      final newTeacherBalance = teacherUser.balance - amount;
      await User.update(
        teacherUserId,
        teacherUser.copyWith(balance: newTeacherBalance),
      );

      // 6. Refund 100% to learner
      final newLearnerBalance = learnerUser.balance + amount;
      await User.update(
        learnerUserId,
        learnerUser.copyWith(balance: newLearnerBalance),
      );

      // 7. Record transaction
      final transaction = MoneyTransaction(
        fromUserId: teacherUserId,
        toUserId: learnerUserId,
        amount: amount,
        type: TransactionType.refund,
        classSessionId: classSessionId,
        enrollmentId: enrollmentId,
        createdAt: DateTime.now(),
        status: 'completed',
        description:
            '100% refund for cancelled session $classSessionId - ฿${amount.toStringAsFixed(2)} returned to learner',
      );

      _localTransactions.add(transaction);

      return transaction;
    } on ApiException catch (e) {
      throw Exception(
        'Refund failed: ${e.body ?? 'Unknown error (${e.statusCode})'}',
      );
    } catch (e) {
      throw Exception('Refund failed: ${e.toString()}');
    }
  }

  /// Rollback a transaction (for error recovery)
  static Future<void> rollbackTransaction(MoneyTransaction transaction) async {
    try {
      if (transaction.status != 'completed') {
        return; // Only rollback completed transactions
      }

      // Get current balances
      final fromUser = await User.fetchById(transaction.fromUserId);
      final toUser = await User.fetchById(transaction.toUserId);

      // Reverse the transaction
      final newFromBalance = fromUser.balance + transaction.amount;
      final newToBalance = toUser.balance - transaction.amount;

      if (newToBalance < 0) {
        throw Exception('Cannot rollback: insufficient balance');
      }

      // Update balances
      await User.update(
        transaction.fromUserId,
        fromUser.copyWith(balance: newFromBalance),
      );
      await User.update(
        transaction.toUserId,
        toUser.copyWith(balance: newToBalance),
      );

      // Mark transaction as reversed
      final reversedTransaction = MoneyTransaction(
        id: transaction.id,
        fromUserId: transaction.toUserId,
        toUserId: transaction.fromUserId,
        amount: transaction.amount,
        type: transaction.type,
        classSessionId: transaction.classSessionId,
        enrollmentId: transaction.enrollmentId,
        createdAt: DateTime.now(),
        status: 'reversed',
        description: 'Rollback: ${transaction.description}',
      );

      _localTransactions.add(reversedTransaction);
    } catch (e) {
      throw Exception('Rollback failed: ${e.toString()}');
    }
  }

  /// Get transaction history for a user
  static Future<List<MoneyTransaction>> getTransactionHistory({
    required int userId,
    TransactionType? filterType,
  }) async {
    final userTransactions = _localTransactions.where(
      (t) => t.fromUserId == userId || t.toUserId == userId,
    );

    if (filterType != null) {
      return userTransactions.where((t) => t.type == filterType).toList();
    }

    return userTransactions.toList();
  }

  /// Clear local transaction history (for testing/development)
  static void clearTransactionHistory() {
    _localTransactions.clear();
  }

  /// Get transaction summary for display
  static String getTransactionSummary(MoneyTransaction transaction) {
    final amountStr = '฿${transaction.amount.toStringAsFixed(2)}';
    switch (transaction.type) {
      case TransactionType.enrollment:
        return 'Paid $amountStr for class enrollment';
      case TransactionType.refund:
        return 'Refunded $amountStr (100% refund)';
      case TransactionType.teacherPayment:
        return 'Received $amountStr from student';
    }
  }
}

double _parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
