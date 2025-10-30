import 'package:flutter/material.dart';
import 'package:tutorium_frontend/pages/home/teacher/register/payment_screen.dart';
import 'package:tutorium_frontend/service/teacher_registration_service.dart';
import 'package:tutorium_frontend/util/local_storage.dart';
import 'package:tutorium_frontend/util/cache_user.dart';

class TeacherRegisterPage extends StatefulWidget {
  const TeacherRegisterPage({super.key});

  @override
  State<TeacherRegisterPage> createState() => _TeacherRegisterPage();
}

class _TeacherRegisterPage extends State<TeacherRegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isCheckingEligibility = true;
  TeacherEligibilityResult? _eligibility;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkEligibility() async {
    setState(() {
      _isCheckingEligibility = true;
    });

    try {
      final userId = await LocalStorage.getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      setState(() {
        _userId = userId;
      });

      debugPrint("DEBUG TeacherReg: Checking eligibility for user $userId");

      final eligibility =
          await TeacherRegistrationService.checkTeacherEligibility(userId);

      if (!mounted) return;

      setState(() {
        _eligibility = eligibility;
        _isCheckingEligibility = false;
      });

      debugPrint(
        "DEBUG TeacherReg: Eligibility result - isEligible=${eligibility.isEligible}, isAlreadyTeacher=${eligibility.isAlreadyTeacher}",
      );

      // ถ้าเป็น Teacher อยู่แล้ว ให้กลับไปหน้าหลัก
      if (eligibility.isAlreadyTeacher) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are already a teacher!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true เพื่อ refresh
      }
    } catch (e) {
      debugPrint("ERROR TeacherReg: Failed to check eligibility: $e");

      if (!mounted) return;

      setState(() {
        _isCheckingEligibility = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check eligibility: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_userId == null || _eligibility == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for eligibility check')),
      );
      return;
    }

    // ตรวจสอบเงินอีกครั้ง
    if (!_eligibility!.hasEnoughBalance) {
      _showInsufficientBalanceDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("DEBUG TeacherReg: Starting registration process");

      final result = await TeacherRegistrationService.registerAsTeacher(
        userId: _userId!,
        email: _emailController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        debugPrint(
          "DEBUG TeacherReg: Registration successful, teacher ID=${result.teacherId}",
        );

        // Clear user cache เพื่อให้ refresh ข้อมูลใหม่
        UserCache().clear();

        if (!mounted) return;

        // แสดงข้อความสำเร็จ
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Success!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Congratulations! You are now a teacher!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Teacher ID: ${result.teacherId}'),
                Text(
                  'New Balance: ${result.newBalance?.toStringAsFixed(2) ?? '0.00'} THB',
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // ปิด dialog
                  Navigator.of(
                    context,
                  ).pop(true); // กลับไปหน้าหลักพร้อม refresh
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Start Teaching!'),
              ),
            ],
          ),
        );
      } else {
        debugPrint("DEBUG TeacherReg: Registration failed - ${result.message}");

        if (result.insufficientBalance) {
          _showInsufficientBalanceDialog(
            currentBalance: result.currentBalance,
            requiredFee: result.requiredFee,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("ERROR TeacherReg: Registration failed: $e");

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInsufficientBalanceDialog({
    double? currentBalance,
    double? requiredFee,
  }) {
    final balance = currentBalance ?? _eligibility?.currentBalance ?? 0.0;
    final fee = requiredFee ?? _eligibility?.requiredFee ?? 200.0;
    final shortfall = fee - balance;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Text('Insufficient Balance'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You do not have enough balance to register as a teacher.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildBalanceRow(
                    'Current Balance:',
                    '${balance.toStringAsFixed(2)} THB',
                  ),
                  const Divider(),
                  _buildBalanceRow(
                    'Required Fee:',
                    '${fee.toStringAsFixed(2)} THB',
                    valueColor: Colors.blue,
                  ),
                  const Divider(),
                  _buildBalanceRow(
                    'Shortfall:',
                    '${shortfall.toStringAsFixed(2)} THB',
                    valueColor: Colors.red,
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop(); // ปิด dialog

              // ไปหน้าเติมเงิน
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaymentScreen(userId: _userId!),
                ),
              );

              // ถ้าเติมเงินสำเร็จ ให้ refresh และกลับมาหน้านี้
              if (result == true) {
                if (!mounted) return;
                await _checkEligibility();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Balance updated! Please complete your registration.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_circle),
            label: const Text('Add Credit'),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingEligibility) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Become a Teacher'),
          backgroundColor: Colors.lightGreen,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking your eligibility...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Teacher'),
        backgroundColor: Colors.lightGreen,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                "Teacher Registration",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Balance info
              if (_eligibility != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _eligibility!.hasEnoughBalance
                        ? Colors.green[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _eligibility!.hasEnoughBalance
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _eligibility!.hasEnoughBalance
                            ? Icons.check_circle
                            : Icons.warning,
                        color: _eligibility!.hasEnoughBalance
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Balance: ${_eligibility!.currentBalance.toStringAsFixed(2)} THB',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Registration Fee: ${_eligibility!.requiredFee.toStringAsFixed(2)} THB',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Description
              const Text(
                "One-time registration fee of 200 THB ensures teacher verification and helps maintain a safe platform for all learners.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Benefits
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.lightGreen[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "What you'll get:",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBenefit(
                      Icons.class_rounded,
                      'Create your own classes',
                    ),
                    _buildBenefit(
                      Icons.attach_money,
                      'Earn income from teaching',
                    ),
                    _buildBenefit(Icons.dashboard, 'Teacher dashboard access'),
                    _buildBenefit(
                      Icons.verified_user,
                      'Verified teacher badge',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form
              const Text(
                "Complete Your Profile",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Email field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'teacher@example.com',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'About You',
                  hintText: 'Tell learners about your teaching experience...',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please write a brief description about yourself';
                  }
                  if (value.trim().length < 20) {
                    return 'Description must be at least 20 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Register & Pay 200 THB',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Info text
              const Center(
                child: Text(
                  'Payment will be deducted from your balance',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
