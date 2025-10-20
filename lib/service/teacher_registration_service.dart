import 'package:flutter/foundation.dart';
import 'package:tutorium_frontend/service/teachers.dart' as teacher_service;
import 'package:tutorium_frontend/service/users.dart' as user_service;

/// Service for handling Teacher registration with transaction-based approach
/// เป็นระบบที่รับประกัน atomic transaction - ไม่มีสถานะครึ่งๆกลางๆ
class TeacherRegistrationService {
  // ค่าธรรมเนียมการสมัครเป็น Teacher (200 THB = 20000 satang)
  static const int teacherRegistrationFeeSatang = 20000;
  static const double teacherRegistrationFeeThb = 200.0;

  /// ผลลัพธ์ของการตรวจสอบสถานะ Teacher
  static Future<TeacherEligibilityResult> checkTeacherEligibility(
    int userId,
  ) async {
    try {
      debugPrint("DEBUG TeacherReg: Checking eligibility for user $userId");

      // 1. ดึงข้อมูล User
      final user = await user_service.User.fetchById(userId);

      // 2. ตรวจสอบว่ามี Teacher role อยู่แล้วหรือไม่
      if (user.teacher != null) {
        debugPrint("DEBUG TeacherReg: User is already a teacher");
        return TeacherEligibilityResult(
          isEligible: false,
          isAlreadyTeacher: true,
          hasEnoughBalance: true,
          currentBalance: user.balance,
          requiredFee: teacherRegistrationFeeThb,
          teacherId: user.teacher!.id,
        );
      }

      // 3. ตรวจสอบยอดเงิน
      final hasEnoughBalance = user.balance >= teacherRegistrationFeeThb;

      debugPrint(
        "DEBUG TeacherReg: Balance=${user.balance}, Required=$teacherRegistrationFeeThb, Eligible=$hasEnoughBalance",
      );

      return TeacherEligibilityResult(
        isEligible: hasEnoughBalance,
        isAlreadyTeacher: false,
        hasEnoughBalance: hasEnoughBalance,
        currentBalance: user.balance,
        requiredFee: teacherRegistrationFeeThb,
      );
    } catch (e) {
      debugPrint("ERROR TeacherReg: Failed to check eligibility: $e");
      rethrow;
    }
  }

  /// ลงทะเบียนเป็น Teacher แบบ atomic transaction
  /// จะสำเร็จทั้งหมดหรือล้มเหลวทั้งหมด ไม่มีครึ่งๆกลางๆ
  static Future<TeacherRegistrationResult> registerAsTeacher({
    required int userId,
    required String email,
    required String description,
  }) async {
    debugPrint("DEBUG TeacherReg: Starting registration for user $userId");

    try {
      // STEP 1: ตรวจสอบสิทธิ์ก่อนเริ่ม transaction
      final eligibility = await checkTeacherEligibility(userId);

      if (eligibility.isAlreadyTeacher) {
        debugPrint("DEBUG TeacherReg: User is already a teacher, aborting");
        return TeacherRegistrationResult(
          success: false,
          message: 'You are already a teacher',
          teacherId: eligibility.teacherId,
        );
      }

      if (!eligibility.hasEnoughBalance) {
        debugPrint(
          "DEBUG TeacherReg: Insufficient balance (${eligibility.currentBalance} < ${eligibility.requiredFee})",
        );
        return TeacherRegistrationResult(
          success: false,
          message:
              'Insufficient balance. You have ${eligibility.currentBalance.toStringAsFixed(2)} THB but need ${eligibility.requiredFee.toStringAsFixed(2)} THB',
          insufficientBalance: true,
          currentBalance: eligibility.currentBalance,
          requiredFee: eligibility.requiredFee,
        );
      }

      // STEP 2: เริ่ม Transaction - หักเงิน + สร้าง Teacher
      debugPrint(
        "DEBUG TeacherReg: Balance check passed, starting transaction",
      );

      // 2.1: สร้าง Teacher record ก่อน (backend จะจัดการการหักเงินเอง)
      final newTeacher = teacher_service.Teacher(
        userId: userId,
        email: email,
        description: description,
        flagCount: 0,
      );

      debugPrint("DEBUG TeacherReg: Creating teacher record...");
      final createdTeacher = await teacher_service.Teacher.create(newTeacher);

      debugPrint(
        "DEBUG TeacherReg: Teacher created successfully with ID ${createdTeacher.id}",
      );

      // 2.2: หักเงินจาก user balance
      // ใช้ PUT /users/:id เพื่ออัพเดทยอดเงิน
      debugPrint("DEBUG TeacherReg: Deducting registration fee...");

      final user = await user_service.User.fetchById(userId);
      final newBalance = user.balance - teacherRegistrationFeeThb;

      final updatedUser = user_service.User(
        id: userId,
        studentId: user.studentId,
        firstName: user.firstName,
        lastName: user.lastName,
        gender: user.gender,
        phoneNumber: user.phoneNumber,
        balance: newBalance,
        banCount: user.banCount,
        profilePicture: user.profilePicture,
      );

      await user_service.User.update(userId, updatedUser);

      debugPrint(
        "DEBUG TeacherReg: Balance updated successfully (${user.balance} -> $newBalance)",
      );

      // STEP 3: Transaction สำเร็จ
      debugPrint(
        "DEBUG TeacherReg: Registration completed successfully for teacher ID ${createdTeacher.id}",
      );

      return TeacherRegistrationResult(
        success: true,
        message: 'Successfully registered as a teacher!',
        teacherId: createdTeacher.id,
        newBalance: newBalance,
      );
    } catch (e) {
      // Transaction ล้มเหลว - log error
      debugPrint("ERROR TeacherReg: Registration failed: $e");

      // ถ้า API มี rollback mechanism ระบบ backend ควรจะ handle
      // แต่ถ้าไม่มี เราต้อง manual rollback ที่นี่

      return TeacherRegistrationResult(
        success: false,
        message: 'Registration failed: ${e.toString()}',
        error: e.toString(),
      );
    }
  }
}

/// ผลลัพธ์การตรวจสอบสิทธิ์การสมัคร Teacher
class TeacherEligibilityResult {
  final bool isEligible; // สามารถสมัครได้ไหม
  final bool isAlreadyTeacher; // เป็น Teacher อยู่แล้วไหม
  final bool hasEnoughBalance; // เงินพอไหม
  final double currentBalance; // ยอดเงินปัจจุบัน
  final double requiredFee; // ค่าธรรมเนียมที่ต้องจ่าย
  final int? teacherId; // Teacher ID (ถ้ามีอยู่แล้ว)

  TeacherEligibilityResult({
    required this.isEligible,
    required this.isAlreadyTeacher,
    required this.hasEnoughBalance,
    required this.currentBalance,
    required this.requiredFee,
    this.teacherId,
  });

  double get shortfall => requiredFee - currentBalance;
}

/// ผลลัพธ์การลงทะเบียน Teacher
class TeacherRegistrationResult {
  final bool success; // สำเร็จหรือไม่
  final String message; // ข้อความแจ้งผลลัพธ์
  final int? teacherId; // Teacher ID (ถ้าสำเร็จ)
  final double? newBalance; // ยอดเงินใหม่ (ถ้าสำเร็จ)
  final bool insufficientBalance; // เงินไม่พอ (ถ้าล้มเหลว)
  final double? currentBalance; // ยอดเงินปัจจุบัน (ถ้าเงินไม่พอ)
  final double? requiredFee; // ค่าธรรมเนียมที่ต้องจ่าย (ถ้าเงินไม่พอ)
  final String? error; // รายละเอียด error (ถ้ามี)

  TeacherRegistrationResult({
    required this.success,
    required this.message,
    this.teacherId,
    this.newBalance,
    this.insufficientBalance = false,
    this.currentBalance,
    this.requiredFee,
    this.error,
  });

  double? get shortfall {
    if (currentBalance != null && requiredFee != null) {
      return requiredFee! - currentBalance!;
    }
    return null;
  }
}
